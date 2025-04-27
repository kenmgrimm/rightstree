#!/usr/bin/env ruby
# script/patent_problem_solution_console.rb
# Interactive CLI harness for PatentService problem-solution guidance

require_relative '../config/environment'

CYAN = "\e[36m"
YELLOW = "\e[33m"
GREEN = "\e[32m"
MAGENTA = "\e[35m"
RED = "\e[31m"
RESET = "\e[0m"
BORDER = "#{CYAN}#{'='*60}#{RESET}"

puts "\n#{CYAN}=== Patent Problem-Solution Guidance Console ===#{RESET}"
puts "#{MAGENTA}Type your responses to the prompts. Type 'exit' to quit.#{RESET}\n"

messages = []
current_problem = nil
current_solution = nil
first_iteration = true

loop do
  if first_iteration
    puts "[DEBUG] First initiation: calling PatentService.guide_problem_solution for session goal."
    result = PatentService.guide_problem_solution(
      messages: messages,
      user_input: '',
      current_problem: current_problem,
      current_solution: current_solution,
      update_problem: false,
      update_solution: false
    )
    messages = result[:messages]
    problem, solution, chat = PatentService.extract_problem_solution_from_history(messages)
    if chat && !chat.empty?
      puts "\n#{GREEN}AI:#{RESET} #{chat}\n"
    else
      # Fallback: try to show the last assistant message from messages array
      last_assistant_msg = messages.reverse.find { |m| m[:role] == 'assistant' && m[:content] && !m[:content].strip.empty? }
      if last_assistant_msg
        puts "#{YELLOW}[Warning] AI did not provide a valid JSON code block. Showing last assistant message instead.#{RESET}"
        puts "\n#{GREEN}AI:#{RESET} #{last_assistant_msg[:content]}\n"
        puts "[DEBUG] Displayed last assistant message: #{last_assistant_msg[:content].inspect}"
      else
        puts "#{RED}AI did not provide an initial goal message.#{RESET}"
        puts "[DEBUG] Initial AI response invalid: problem=#{problem.inspect}, solution=#{solution.inspect}, chat=#{chat.inspect}"
      end
    end
    first_iteration = false
  end

  puts "\n#{BORDER}"
  puts "#{CYAN}Current State#{RESET}"
  puts "#{CYAN}Problem:  #{YELLOW}#{current_problem.nil? ? '(none)' : current_problem}#{RESET}"
  puts "#{CYAN}Solution: #{YELLOW}#{current_solution.nil? ? '(none)' : current_solution}#{RESET}"
  puts BORDER
  puts "#{MAGENTA}Choose an action:#{RESET}"
  puts "  #{CYAN}1)#{RESET} Update Problem"
  puts "  #{CYAN}2)#{RESET} Update Solution"
  puts "  #{CYAN}3)#{RESET} Chat with AI"
  puts "  #{CYAN}exit)#{RESET} Quit"
  print "#{MAGENTA}> #{RESET}"
  action = STDIN.gets&.strip
  break if action.nil? || action.downcase == 'exit'

  user_input = nil
  case action
  when '1', 'update problem'
    puts "[DEBUG] User chose to update problem"
    print "#{YELLOW}Enter new problem statement: #{RESET}"
    new_problem = STDIN.gets&.strip
    if new_problem && !new_problem.empty?
      current_problem = new_problem
      puts "#{GREEN}[Updated problem]#{RESET}"
    end
  when '2', 'update solution'
    puts "[DEBUG] User chose to update solution"
    print "#{YELLOW}Enter new solution statement: #{RESET}"
    new_solution = STDIN.gets&.strip
    if new_solution && !new_solution.empty?
      current_solution = new_solution
      puts "#{GREEN}[Updated solution]#{RESET}"
    end
  when '3', 'chat'
    puts "[DEBUG] User chose to chat with AI"
    print "#{YELLOW}You: #{RESET}"
    user_input = STDIN.gets&.strip
    if user_input.nil? || user_input.empty?
      puts "[DEBUG] No user input provided for chat. Skipping AI call."
      next
    end
  else
    puts "#{RED}Unknown action. Please choose 1, 2, 3, or 'exit'.#{RESET}"
    next
  end

  # Always call AI after any action
  puts "[DEBUG] Calling PatentService.guide_problem_solution..."
  result = PatentService.guide_problem_solution(
    messages: messages,
    user_input: user_input || '',
    current_problem: current_problem,
    current_solution: current_solution,
    update_problem: false,
    update_solution: false
  )
  messages = result[:messages]
  problem, solution, chat = PatentService.extract_problem_solution_from_history(messages)
  if problem.nil? || solution.nil? || chat.nil?
    puts "#{RED}AI response was invalid or not in the required format. Please try again or rephrase your input.#{RESET}"
    puts "[DEBUG] AI response invalid: problem=#{problem.inspect}, solution=#{solution.inspect}, chat=#{chat.inspect}"
    next
  end
  puts "\n#{GREEN}AI:#{RESET} #{chat}\n"
  # Offer to update problem/solution if AI suggests changes
  if current_solution.nil? || current_solution.strip.empty?
    if problem != current_problem
      puts "#{CYAN}AI suggests a new problem:#{RESET}\n#{YELLOW}#{problem}#{RESET}"
      print "#{MAGENTA}Accept this as the new problem? (y/N): #{RESET}"
      confirm = STDIN.gets&.strip
      if confirm&.downcase == 'y'
        current_problem = problem
        puts "#{GREEN}[Problem updated]#{RESET}"
        puts "[DEBUG] Problem updated via AI suggestion"
      end
    end
  else
    if problem != current_problem
      puts "#{CYAN}AI suggests a new problem:#{RESET}\n#{YELLOW}#{problem}#{RESET}"
      print "#{MAGENTA}Accept this as the new problem? (y/N): #{RESET}"
      confirm = STDIN.gets&.strip
      if confirm&.downcase == 'y'
        current_problem = problem
        puts "#{GREEN}[Problem updated]#{RESET}"
        puts "[DEBUG] Problem updated via AI suggestion"
      end
    end
    if solution != current_solution
      puts "#{CYAN}AI suggests a new solution:#{RESET}\n#{YELLOW}#{solution}#{RESET}"
      print "#{MAGENTA}Accept this as the new solution? (y/N): #{RESET}"
      confirm = STDIN.gets&.strip
      if confirm&.downcase == 'y'
        current_solution = solution
        puts "#{GREEN}[Solution updated]#{RESET}"
        puts "[DEBUG] Solution updated via AI suggestion"
      end
    end
  end
  puts "[DEBUG] End of loop iteration: problem=#{current_problem.inspect}, solution=#{current_solution.inspect}"
end

puts "\n#{CYAN}Session ended. Goodbye!#{RESET}"
