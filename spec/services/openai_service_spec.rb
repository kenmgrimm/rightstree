# spec/services/openai_service_spec.rb
require "rails_helper"

describe OpenaiService do
  let(:service) { described_class.new(model: "gpt-3.5-turbo") }
  let(:messages) { [ { role: "user", content: "Say hello as a test." } ] }

  before do
    # Prevent real API calls
    allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return({ "choices"=>[ { "message"=>{ "content"=>"Hello from OpenAI!" } } ] })
  end

  it "returns a chat completion response" do
    response = service.chat(messages)
    expect(response).to be_a(Hash)
    expect(response["choices"]).to be_an(Array)
    expect(response["choices"].first["message"]["content"]).to eq("Hello from OpenAI!")
  end

  it "raises if API key is missing" do
    allow(Rails.application.credentials).to receive(:OPENAI_API_TOKEN).and_return(nil)
    allow(ENV).to receive(:[]).with("OPENAI_API_TOKEN").and_return(nil)
    expect {
      described_class.new.fetch_api_key
    }.to raise_error("OpenAI API key missing!")
  end
end
