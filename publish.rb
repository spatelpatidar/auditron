# frozen_string_literal: true

# -----------------------------------------------------------------------------
# publish.rb — Cross-platform publish pipeline (Windows / Mac / Linux)
# Usage: ruby publish.rb
# -----------------------------------------------------------------------------

def colorize(text, code) = "\e[#{code}m#{text}\e[0m"
def green(text) = colorize(text, 32)
def blue(text)  = colorize(text, 34)
def red(text)   = colorize(text, 31)

def run!(cmd)
  puts blue("  $ #{cmd}")
  system(cmd) || abort(red("❌  Command failed: #{cmd}"))
end

puts blue("=" * 60)
puts blue("   Starting Publish Pipeline for Auditron")
puts blue("=" * 60)

# Step 1: Clean -> move old gems to Gems/
puts "\n#{blue("Step 1: Moving old gem files to Gems/...")}"
run!("bundle exec rake publish:clean")
puts green("✅  Clean done.")

# Step 2: RuboCop
puts "\n#{blue("Step 2: Running RuboCop...")}"
run!("bundle exec rake publish:lint")

# Step 3: Run specs
puts "\n#{blue("Step 3: Running RSpec suite...")}"
run!("bundle exec rake publish:spec")
puts green("✅  Specs passed.")

# Step 4: Build gem
puts "\n#{blue("Step 4: Building gem...")}"
run!("bundle exec rake publish:build")

# Step 5: Push to RubyGems (you will be asked for your MFA/OTP code)
puts "\n#{blue("Step 5: Pushing to RubyGems...")}"
abort red("❌  No .gem file found. Build might have failed.") if Dir["*.gem"].empty?
run!("bundle exec rake publish:push")

puts "\n#{green("=" * 60)}"
puts green("🎉  Done! Auditron is now live on RubyGems.org")
puts green("=" * 60)