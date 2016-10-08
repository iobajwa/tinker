
[
	"tool_messages",
].each {  |req| require "#{File.expand_path(File.dirname(__FILE__))}/#{req}" }


class Variable
	attr_accessor :name, :size, :type, :address, :default_value, :memory_name
	attr_accessor :is_array, :array_depth

	def initialize(name, size, type, address, default_value, memory, array=false, array_depth=0)
		@name          = name
		@size          = size
		@type          = type
		@address       = address
		@default_value = default_value
		@memory_name   = memory
		@is_array      = array
		@array_depth   = array_depth
	end

	# converts higher-level 'value' to lower-level byte stream (byte-array; encoding: little-endian) 
	# based upon the variable.type
	def serialize(value)
		return [] if value == nil

		bytes = []

		begin
			if @is_array
				raise ToolException.new "cannot serialize variable '#{@name}' because array_depth < 1" unless @array_depth > 0
				
				if @type.downcase == "char" && value.class == String
					
					bytes = value.bytes
					bytes.push 0
					raise ToolException.new "passed string value.length ('#{bytes.length}') > variable's array_depth ('#{@array_depth}')" if bytes.length > @array_depth
					(@array_depth - bytes.length).times { bytes.push 0 }      # pad any remaining slots with '\0'

				else

					value = Array.new(@array_depth, value) unless value.class == Array
					raise ToolException.new "cannot serialize variable '#{@name}' because passed array value.length != array_depth" unless value.length == @array_depth
					i = 1
					value.each {  |v|
						t = serialize_value v
						raise ToolException.new "invalid value '#{v}' at index #{i} for variable '#{@name}' of type '#{@type}'" if t == nil
						bytes.push t
						i += 1
					}
				end
			else
				bytes = serialize_value value
				raise ToolException.new "invalid value '#{value}' for variable '#{@name}' of type '#{@type}'" if bytes == nil
			end
		rescue ToolException => ex
			raise ToolException.new "variable.serialize: " + ex.message
		end

		return bytes.flatten
	end

	# converts higher-level 'value' from lower-level byte_stream (byte-array) based upon it's type
	def deserialize(raw)
		raise "Not Implemented!"
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


	private

	def serialize_value(value)
		bytes = []

		case @type.downcase
			when "bool"
				v = value.to_s.downcase
				return nil if v != "true" && v != "false"
				bytes = (v == "true") ? [1] : [0]
			when "char"
				bytes = [ value.to_s.bytes[0] ]
			when /(u|h|i|s|c)[1-9]{1,2}/i   # integers
				@size.times {
					bytes.push value & 0xff
					value >>= 8
				}
			else raise ToolException.new "cannot serialize variable '#{@name}' of type '#{@type}'"
		end

		# we were assuming the host-computer has little endian format all along
		return @@little_endian ? bytes : bytes.reverse
	end



	public

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

		raise ToolException.new "Variable.parse: size missing for '#{name}' variable"             unless size
		raise ToolException.new "Variable.parse: type missing for '#{name}' variable"             unless type
		raise ToolException.new "Variable.parse: address missing for '#{name}' variable"          unless address
		raise ToolException.new "Variable.parse: value missing for '#{name}' variable"            unless value
		raise ToolException.new "Variable.parse: memory_name missing for '#{name}' variable"      unless memory_name

		raise ToolException.new "Variable.parse: size must be a number for '#{name}' variable"    unless size.class == Fixnum
		raise ToolException.new "Variable.parse: type must be a string for '#{name}' variable"    unless type.class == String
		raise ToolException.new "Variable.parse: address must be a number for '#{name}' variable" unless address.class == Fixnum

		raise ToolException.new "Variable.parse: size cannot be less than 1 for '#{name}' variable" if size < 1
		raise ToolException.new "Variable.parse: address cannot be negative for '#{name}' variable" if address < 0

		return Variable.new name, size, type, address, value, memory_name
	end

	@@little_endian = ([1,0,0,0].pack("i") == "\001\000\000\000") ? true : false
end
