# Initial Project Requirements: Rails AI Patent Marketplace

## Tech Stack
- **Version Manager:** [mise](https://github.com/jdx/mise) (for Ruby, Node, Postgres, etc.)
- **Language:** Ruby (latest stable)
- **Framework:** Rails (latest stable)
- **Database:** PostgreSQL
- **Testing:**
  - RSpec (unit/integration testing)
  - FactoryBot (test data factories)
  - WebMock (HTTP stubbing/mocking)

## Setup Requirements
- Install [mise](https://github.com/jdx/mise) for unified toolchain management
- Use `.tool-versions` to specify required versions for Ruby, Node, and Postgres
- Initialize Rails project with `--database=postgresql`
- Add and configure RSpec, FactoryBot, and WebMock in the Gemfile and test setup

## .tool-versions Example
```
ruby latest
node latest
```

## Gems to Include
- rails
- pg
- rspec-rails
- factory_bot_rails
- webmock

## Test Setup
- Configure RSpec as default test suite
- Integrate FactoryBot for factories
- Enable WebMock for HTTP request stubbing in tests

## Code Quality & Linting
- Use RuboCop and RuboCop Rails for Ruby and Rails code style enforcement
- Default config inherits from `rubocop-rails-omakase` for community best practices
- Run `bundle exec rubocop` to check or auto-correct code style

## Version Control
- Initialize Git repository
- Add `.gitignore` for Rails, Ruby, Node, and editor/OS artifacts

## Next Steps
1. Scaffold new Rails app
2. Set up mise and `.tool-versions`
3. Configure database and test stack
4. Commit initial project files to version control
