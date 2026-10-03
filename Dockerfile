FROM ruby:4-alpine
WORKDIR /usr/src/harness
COPY Gemfile Gemfile.lock ./
# The precompiled gem for the platform (x86_64-linux-musl or aarch64-linux-musl).
RUN bundle install
COPY bowtie_corvus_json_schema.rb .
CMD ["bundle", "exec", "ruby", "bowtie_corvus_json_schema.rb"]
