#!/usr/bin/env ruby

require 'pathname'
require 'cgi'
require 'open-uri'
require 'yaml'
require 'json'
require 'net/http'
require 'readline'
require 'ostruct'
include Readline

# CHANGE PWD TO REAL PATH
base = $0
while File.symlink? base
  base = File.readlink base
end
Dir.chdir(Pathname.new(base).parent) unless base == $0

CARDS = YAML.load_file("cards.yml").map(&:last).map(&OpenStruct.method(:new))
CLASSES =  {
  1 => "Druid",
  2 => "Hunter",
  3 => "Mage",
  4 => "Paladin",
  5 => "Priest",
  6 => "Rogue",
  7 => "Shaman",
  8 => "Warlock",
  9 => "Warrior"
}
CATEGORIES = {
  "Free" => 0,
  "Common" => 0,
  "Rare" => 1,
  "Epic" => 2,
  "Legendary" => 3
}

def url_for(hs_class, decklist, choices)
  raise ArgumentError, "3 choices max!" if choices.length > 3
  decklist = [ "-" ] if decklist.empty?
  choices << 471 until choices.length == 3
  [
    "http://draft.heartharena.com/arena/option-multi-score",
    hs_class,
    decklist.join("-"),
    choices.join("-")
  ].join("/")
end

def fuzzy_find(input, collection)
  regex = if /^(?:"|')(.*)(?:"|')$/ =~ input
    Regexp.new(['^', Regexp.escape($1), '$'].join, Regexp::IGNORECASE)
  else
    Regexp.new(
      '\b' + input.chars.map(&Regexp.method(:escape)).join(".*"),
      Regexp::IGNORECASE
    )
  end
  collection.select do |entry|
    value = block_given? ? yield(entry) : entry
    regex =~ value
  end
end

selected_class = nil
class_value = nil
loop do
  selected_class = (ARGV.shift || readline("Choose class: ")).capitalize
  class_value = CLASSES.invert[selected_class]

  break if CLASSES.values.include? selected_class
  puts "No such class: #{selected_class}."
  puts "Choose between: #{CLASSES.values.join(", ")}"
end

CARDS.keep_if do |card|
  !card.to_h.key?(:class) or card[:class] == selected_class
end

deck = []
choices = []
error = nil
loop do
  begin
    command = readline "> "
    case command
    when nil
      puts
      exit # EOF
    when /\Al(?:s|ist)?(?: (.+))?\z/
      sep = case $1
      when /,/ then ", "
      when /;/ then "; "
      else "\n"
      end
      puts deck.map(&:name).join(sep)
    when /\Ac(?:hoices)?\z/
      puts choices.map(&:name).join(", ")
    when /\Ad(?:delete)? (.*)\z/
      matches = fuzzy_find($1, deck, &:name).uniq
      if matches.length > 1
        puts "Multiple matches: #{matches.map(&:name).join(", ")}"
      elsif matches.length == 1
        puts "Deleting #{matches.first.name}"
        deck.delete_at deck.index(matches.first)
      else
        puts "No matches"
      end
    when /\Ap(?:ick)? (.*)\z/
      selection = $1
      if i = Integer(selection) rescue false
        choice = choices[i - 1]
        puts "Picking #{choice.name}"
        deck << choice
        choices = []
      else
        matches = fuzzy_find(selection, CARDS, &:name)
        if matches.length == 1
          puts "Picking #{matches.first.name}"
          deck << matches.first
        elsif matches.length > 1
          puts "Multiple matches: #{matches.map(&:name).join(", ")}"
        else
          puts "No cards found."
        end
      end
      puts "Deck limit reached. Command `s` to submit" if deck.length == 30
    when /\As(?:ubmit|ave)?\z/
      if deck.length == 30
        choices = deck.map do |card|
          {picked: card.id, options: [card.id, 471, 471]}
        end
        puts "To submit the draft, go to heartharena.com, login and enter this in the console:"
        puts <<-EOF.gsub(/\s+/, ' ').strip
        $.ajax({
          type: "POST",
          url: "/arena/save/#{class_value}",
          data: #{{choices: choices}.to_json},
          success: function(data) {
            if(data.success) window.location = data.redirect;
          }
        })
        EOF
      elsif deck.length > 30
        puts "Too many cards! HAVE: #{deck.length}, NEED: 30"
      else
        puts "Not enough cards! HAVE: #{deck.length}, NEED: 30"
      end
    when /\A(?:f(?:ind)?|q(?:uery)?) (.*)\z/
      pat = $1
      matches = fuzzy_find(pat, CARDS, &:name).map(&:name)
      if matches.length <= 20
        puts matches.join(", ")
      else
        puts "Over 20 matches, omitting..."
      end
    when / vs /
      choices = command.split(" vs ").map do |input|
        matches = nil
        loop do
          matches = fuzzy_find(input, CARDS, &:name)
          break unless matches.length == 0
          input = readline("No result for #{input}. Try again: ")
        end
        [input, matches]
      end
      rarity = nil
      valid = true
      # puts JSON.pretty_generate choices
      choices.sort_by { |_, ms| ms.length }.each do |input, matches|
        if rarity
          matches.keep_if do |match|
            CATEGORIES[match.rarity] == rarity
          end
        elsif matches.length == 1
          rarity = CATEGORIES[matches.first.rarity]
          next
        end
        next if matches.length == 1
        valid = false
        if matches.length == 0
          $stdout.puts "No cards found for #{input}."
        else
          $stdout.puts "Multiple cards match #{input}: #{matches.map(&:name).join(", ")}"
        end
      end
      if valid
        choices.map!(&:last).map!(&:last)
        url = url_for(class_value, deck.map(&:id), choices.map(&:id))
        hash = JSON.parse(open(url).read)
        length = choices.map(&:name).map(&:length).max
        results = hash["results"]
        results.pop until results.length == choices.length
        results.each do |result|
          puts [
            result["card"]["name"].ljust(length),
            "%.2f" % result["card"]["score"],
            "Synergies: " + result["card"]["synergies"].join(", ")
          ].join(" - ")
        end
        puts hash["tip"]["text"]
      end
    when /^e(?:rr(?:or)?)?$/
      p error
      puts error.backtrace
    when /\?|help|m/
      puts "Available commands are:"
      puts "f[ind] / q[uery] `expr`   list all cards that match `expr`"
      puts "p[ick] `expr`             pick the card that matches `expr`"
      puts "`e1` vs `e2` [vs `e3`]    ask Heartharena.com to compare the cards matching `e1`-`e3`"
      puts "                          The cards will be stored to enable picking via"
      puts "                          `p 1`, `p 2` or `p 3` in a subsequent command"
      puts "                          e.g.: `Wisp vs Ogre Brute` and then `p 2` to pick Ogre"
      puts "c[hoices]                 Show the last choices that were stored (from above command)"
      puts "l[ist|s]                  List the current drafted deck"
      puts "e[rr[or]]                 Show the last error message with debug info"
      puts "d[elete] `expr`           Deletes the card from the deck that matches `expr`"
      puts "s[ubmit|ave]              Output script to persist the drafted deck for heartharena.com"
      puts "?|help|m                  Print this help"
      puts
    else
      puts "Could not match command"
      next
    end
    Readline::HISTORY << command
  rescue => e
    error = e
    puts "Error: #{e.message}"
  end
end
