FROM jekyll/jekyll:4.2.0

# Install github-pages gem dependencies
RUN apk add --no-cache --virtual .build-deps \
    build-base \
    libxml2-dev \
    libxslt-dev \
    nodejs \
    npm

# Create working directory
WORKDIR /srv/jekyll

# Copy Gemfile first for better caching
COPY Gemfile ./

# Install gems
RUN bundle install

# Copy the rest of the site
COPY . .

# Expose port
EXPOSE 4000

# Run Jekyll
CMD ["jekyll", "serve", "--host", "0.0.0.0", "--watch", "--force_polling"]