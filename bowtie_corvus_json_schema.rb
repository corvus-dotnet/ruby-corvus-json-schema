# frozen_string_literal: true

# A Bowtie (https://github.com/bowtie-json-schema/bowtie) harness for the corvus_json_schema gem.
#
# It speaks IHOP (one JSON request per line on standard input, one response per line on standard output):
# - `start` reports the implementation and its dialects;
# - `dialect` sets the dialect for schemas without `$schema`;
# - `run` compiles the case's schema with the case's `registry` as the document resolver and validates each instance
#   (for `annotations` output, through a verbose collector, reporting each annotation with its instance location and
#   `#…` keyword location);
# - `stop` exits.
require "json"
require "corvus_json_schema"

DIALECTS = {
  "https://json-schema.org/draft/2020-12/schema" => :draft202012,
  "https://json-schema.org/draft/2019-09/schema" => :draft201909,
  "http://json-schema.org/draft-07/schema#" => :draft7,
  "http://json-schema.org/draft-06/schema#" => :draft6,
  "http://json-schema.org/draft-04/schema#" => :draft4
}.freeze

def errored(error)
  { errored: true, context: { message: error.message, traceback: (error.backtrace || []).join("\n") } }
end

def strip_fragment(uri)
  uri.split("#", 2).first
end

# Characters a URI fragment keeps unencoded.
FRAGMENT_SAFE = /\A[A-Za-z0-9\-._~!$&'()*+,;=:@\/?]\z/

# Percent-encodes text as a URI fragment does (upper-case hex, UTF-8).
def percent_encode(text)
  text.b.each_char.map { |c| c.ord < 128 && c.match?(FRAGMENT_SAFE) ? c : format("%%%02X", c.ord) }.join
end

# The annotations a verbose collector grouped (instance location, then keyword as a JSON-pointer token, then schema
# location as a `#…` fragment; the same in every Corvus implementation) as Bowtie lists them: each with its keyword
# unescaped, and its keyword location the schema location's fragment followed by `/` and the keyword token,
# percent-encoded as the fragment is.
def annotations_of(grouped)
  grouped.flat_map do |instance_location, keywords|
    keywords.flat_map do |token, locations|
      locations.map do |schema_location, value|
        {
          keyword: token.gsub("~1", "/").gsub("~0", "~"),
          instanceLocation: instance_location,
          keywordLocation: "#{schema_location}/#{percent_encode(token)}",
          annotation: value
        }
      end
    end
  end
end

started = false
dialect = :draft202012

$stdout.sync = true
$stdin.each_line do |line|
  next if line.strip.empty?

  request = JSON.parse(line)
  response =
    case request["cmd"]
    when "start"
      raise "Unsupported IHOP version #{request["version"].inspect}" unless request["version"] == 1

      started = true
      {
        version: 1,
        implementation: {
          language: "ruby",
          name: "corvus-json-schema",
          version: CorvusJsonSchema::VERSION,
          homepage: "https://github.com/corvus-dotnet/Corvus.JsonSchema",
          documentation: "https://rubygems.org/gems/corvus_json_schema",
          issues: "https://github.com/corvus-dotnet/Corvus.JsonSchema/issues",
          source: "https://github.com/corvus-dotnet/Corvus.JsonSchema",
          dialects: DIALECTS.keys,
          os: RbConfig::CONFIG["host_os"],
          os_version: File.exist?("/proc/sys/kernel/osrelease") ? File.read("/proc/sys/kernel/osrelease").strip : "",
          language_version: RUBY_VERSION
        }
      }
    when "dialect"
      raise "Not started" unless started

      if DIALECTS.key?(request["dialect"])
        dialect = DIALECTS.fetch(request["dialect"])
        { ok: true }
      else
        { ok: false }
      end
    when "run"
      raise "Not started" unless started

      case_ = request["case"]
      seq = request["seq"]
      registry = (case_["registry"] || {}).to_h { |uri, schema| [strip_fragment(uri), schema] }
      begin
        validator = CorvusJsonSchema.compile(case_["schema"], default_dialect: dialect,
                                                              resolver: ->(uri) { registry[strip_fragment(uri)] })
        annotations = request["output"] == "annotations"
        results = case_["tests"].map do |test|
          if annotations
            collector = CorvusJsonSchema::Collector.new(:verbose)
            valid = validator.evaluate(test["instance"], collector)
            { valid: valid, annotations: annotations_of(collector.annotations) }
          else
            { valid: validator.valid?(test["instance"]) }
          end
        rescue StandardError => e # an error for one instance does not stop the others
          errored(e)
        end
        { seq: seq, results: results }
      rescue StandardError => e # every compilation failure is reported for the case
        { seq: seq, **errored(e) }
      end
    when "stop"
      raise "Not started" unless started

      exit(0)
    else
      raise "Unknown command #{request["cmd"].inspect}"
    end
  puts JSON.generate(response)
end
