
[
	"tool_messages",
	"variable",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }

class SymbolManager
	attr_accessor :symbols
	
	def initialize(symbols)
		@symbols = symbols
	end

	def [](variable_name)
		return unless @symbols
		variable_name.downcase!

		@symbols.each {  |v|
			return v if v.name.downcase == variable_name
		}
		return nil
	end

	def SymbolManager.parse(raw)
		return nil unless raw
		return nil unless raw.class == Hash
		vars = []
		raw.each_pair {  |n, v|
			name = n.to_s
			raise ToolException.new "SymbolManager.parse: metadata missing for '#{n}' variable" unless v
			size    = v[:size]
			type    = v[:type]
			address = v[:address]
			value   = v[:value]
			raise ToolException.new "SymbolManager.parse: size missing for '#{n}' variable" unless size
			raise ToolException.new "SymbolManager.parse: type missing for '#{n}' variable" unless type
			raise ToolException.new "SymbolManager.parse: address missing for '#{n}' variable" unless address
			raise ToolException.new "SymbolManager.parse: value missing for '#{n}' variable" unless value

			raise ToolException.new "SymbolManager.parse: size must be a number for '#{n}' variable" unless size.class == Fixnum
			raise ToolException.new "SymbolManager.parse: type must be a string for '#{n}' variable" unless type.class == String
			raise ToolException.new "SymbolManager.parse: address must be a number for '#{n}' variable" unless address.class == Fixnum

			raise ToolException.new "SymbolManager.parse: size cannot be less than 1 for '#{n}' variable" if size < 1
			raise ToolException.new "SymbolManager.parse: address cannot be negative for '#{n}' variable" if address < 0

			vars.push Variable.new name, size, type, address, value
		}

		return SymbolManager.new vars
	end
end
