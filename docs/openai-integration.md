# OpenAI Integration Requirements

## Purpose
Integrate OpenAI's API to enable AI-powered patent drafting, analysis, and other advanced features within the Rails platform.

## Key Requirements
- Use the official `openai` Ruby gem for API access
- Support secure storage and access of the OpenAI API key
- Provide a clear interface/service layer for interacting with OpenAI
- Enable easy swapping of models (e.g., GPT-4, GPT-3.5) via configuration
- Ensure robust error handling and logging for all API calls
- Respect API rate limits and provide user feedback on failures

## API Key Management: .env vs Rails Credentials
### Recommendation
**Use Rails Encrypted Credentials** for storing the OpenAI API key in production and staging. This is the most secure, Rails-native approach. For local development, `.env` files may be used for convenience, but should be gitignored and never committed.

#### Pros & Cons
| Method        | Pros                                        | Cons                                 |
|--------------|---------------------------------------------|--------------------------------------|
| Rails Credentials | Secure, encrypted, versioned, Rails-native | Requires `EDITOR` setup, less convenient for quick local changes |
| .env Files    | Simple, works with dotenv gem, easy local changes | Not encrypted, risk of accidental commit, not for production    |

### Implementation Guidance
- Store the key as `OPENAI_API_TOKEN` in Rails credentials:
  ```sh
  bin/rails credentials:edit
  # add:
  # OPENAI_API_TOKEN: YOUR_KEY_HERE
  ```
- For local development, add to `.env` and use `dotenv-rails` if desired:
  ```env
  OPENAI_API_TOKEN=YOUR_KEY_HERE
  ```
- Always gitignore `.env*` files and never commit real API keys.

## Next Steps
1. Add `openai` gem to Gemfile
2. Implement service object for OpenAI API calls
3. Load API key from credentials (with fallback to ENV for dev)
4. Add usage examples and error handling
5. Document setup for both credentials and .env
