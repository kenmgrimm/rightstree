require "rails_helper"

RSpec.describe PatentService do
  let(:initial_messages) { [] }

  before do
    # Stub OpenAI response for deterministic tests
    allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return({
      "choices" => [
        { "message" => { "content" => "Problem: Users have difficulty tracking their daily water intake. Solution: A mobile app that reminds users to drink water and logs their intake throughout the day." } }
      ]
    })
  end

  it "guides the user to a clear problem and solution" do
    user_input = "I want to help people drink more water."
    result = described_class.guide_problem_solution(messages: initial_messages, user_input: user_input)
    expect(result[:problem]).to include("Users have difficulty tracking their daily water intake")
    expect(result[:solution]).to include("A mobile app that reminds users to drink water")
    expect(result[:ai_message]).to be_present
    expect(result[:messages].last[:role]).to eq("assistant")
    expect(result[:raw_response]).to be_a(Hash)
  end

  it "redirects off-topic requests" do
    user_input = "Tell me a joke about cats."
    result = described_class.guide_problem_solution(messages: initial_messages, user_input: user_input)
    expect(result[:problem]).to be_nil
    expect(result[:solution]).to be_nil
    expect(result[:ai_message]).to include("Let's focus on defining your problem and solution")
    expect(result[:messages].last[:content]).to include("Let's focus on defining your problem and solution")
    expect(result[:raw_response]).to be_nil
  end

  it "maintains conversation history and asks clarifying questions" do
    # Simulate a multi-turn conversation
    messages = [
      { role: "system", content: PatentService.system_prompt },
      { role: "user", content: "I want to help people drink more water." },
      { role: "assistant", content: "What is the main problem users face with water intake?" },
      { role: "user", content: "They just forget to drink." }
    ]
    allow_any_instance_of(OpenAI::Client).to receive(:chat).and_return({
      "choices" => [
        { "message" => { "content" => "Problem: Users forget to drink water regularly. Solution: An app that sends reminders and tracks water intake." } }
      ]
    })
    result = described_class.guide_problem_solution(messages: messages, user_input: "They just forget to drink.")
    expect(result[:problem]).to include("Users forget to drink water regularly")
    expect(result[:solution]).to include("An app that sends reminders")
    expect(result[:messages].last[:role]).to eq("assistant")
  end
end
