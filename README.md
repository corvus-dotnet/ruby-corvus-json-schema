# ruby-corvus-json-schema

A [Bowtie](https://github.com/bowtie-json-schema/bowtie) test harness for
[corvus_json_schema](https://rubygems.org/gems/corvus_json_schema), the Ruby gem of
[Corvus.JsonSchema](https://github.com/corvus-dotnet/Corvus.JsonSchema): a native extension over the
corvus-json-schema Rust crate.

Its image is published to `ghcr.io/bowtie-json-schema/ruby-corvus-json-schema` and run via
`bowtie run -i ruby-corvus-json-schema`.

The harness compiles each case's schema with the case's `registry` as the document resolver and validates each
instance. For `annotations` output it evaluates through a verbose collector and reports each annotation with its
instance location and `#…` keyword location.

The gem's version is pinned in `Gemfile` and `Gemfile.lock`, which Dependabot keeps at the latest release.
