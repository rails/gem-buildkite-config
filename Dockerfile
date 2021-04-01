ARG RUBY_IMAGE
FROM ${RUBY_IMAGE:-ruby:latest}

WORKDIR /app
ENV JRUBY_OPTS="--dev -J-Xmx1024M"

# Wildcard ignores missing files; .empty ensures ADD always has at least
# one valid source: https://stackoverflow.com/a/46801962
ADD .buildkite/.empty .ci/pre-buil[d] .ci/
ADD .buildkite/runner .buildkite/infer-version-path /usr/local/bin/

ARG BUNDLER
ARG RUBYGEMS
RUN echo "--- :ruby: Updating RubyGems and Bundler" \
    && (gem update --system ${RUBYGEMS:-} || gem update --system 2.7.8) \
    && (gem install bundler -v "${BUNDLER:->= 0}" || gem install bundler -v "< 2") \
    && ruby --version && gem --version && bundle --version \
    && if [ -f ./.ci/pre-build ]; then \
        echo "--- :package: Installing system deps" \
        && chmod +x ./.ci/pre-build \
        && ./.ci/pre-build; \
    fi \
    && chmod +x /usr/local/bin/runner /usr/local/bin/infer-version-path \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/*

ADD .buildkite/.empty lib/*/version.rb lib/.version/
ADD Gemfile Gemfile.loc[k] *.gemspec ./

RUN infer-version-path \
    && echo "--- :bundler: Installing Ruby deps" \
    && rm -rf lib/.version/ Gemfile.lock \
    && bundle install -j 8 \
    && cp Gemfile.lock /tmp/Gemfile.lock.updated \
    && rm -rf /usr/local/bundle/cache \
    && echo "--- :floppy_disk: Copying repository contents"

ADD . ./

RUN mv -f /tmp/Gemfile.lock.updated Gemfile.lock

ENTRYPOINT ["runner"]
CMD ["rake"]
