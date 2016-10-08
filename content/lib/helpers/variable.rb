
[
	"tool_messages",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }


class Variable
	attr_accessor :name, :size, :type, :address, :default_value, :memory_name

	def initialize(name, size, type, address, default_value, memory)
		@name          = name
		@size          = size
		@type          = type
		@address       = address
		@default_value = default_value
		@memory_name   = memory
	end

	def ==(obj)
		return ( @name          == obj.name &&
		         @size          == obj.size &&
		         @type          == obj.type &&
		         @address       == obj.address &&
		         @default_value == obj.default_value &&
		         @memory_name   == obj.memory_name )
	end

	def to_s
		return "#{name} (size='#{@size}', type='#{@type}', address='#{@address}', default_value='#{@default_value}')"
	end


	def Variable.parse(name, metadata)
		return nil unless name
		name = name.to_s
		raise ToolException.new "Variable.parse: metadata missing for '#{name}' variable" unless metadata
		return nil unless metadata.class == Hash
		size        = metadata [:size]
		type        = metadata [:type]
		address     = metadata [:address]
		value       = metadata [:value]
		memory_name = metadata [:memory_name]
		raise ToolException.new "Variable.parse: size missing for '#{name}' variable" unless size
		raise ToolException.new "Variable.parse: type missing for '#{name}' variable" unless type
		raise ToolException.new "Variable.parse: address missing for '#{name}' variable" unless address
		raise ToolException.new "Variable.parse: value missing for '#{name}' variable" unless value
		raise ToolException.new "Variable.parse: memory_name missing for '#{name}' variable" unless memory_name

		raise ToolException.new "Variable.parse: size must be a number for '#{name}' variable" unless size.class == Fixnum
		raise ToolException.new "Variable.parse: type must be a string for '#{name}' variable" unless type.class == String
		raise ToolException.new "Variable.parse: address must be a number for '#{name}' variable" unless address.class == Fixnum

		raise ToolException.new "Variable.parse: size cannot be less than 1 for '#{name}' variable" if size < 1
		raise ToolException.new "Variable.parse: address cannot be negative for '#{name}' variable" if address < 0

		return Variable.new name, size, type, address, value, memory_name
	end
end
