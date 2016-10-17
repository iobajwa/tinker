
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
		bytes = []

		if value == nil
			size = @size
			size *= @array_depth if @is_array
			size.times { bytes.push nil }
			return bytes
		end

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
		read_value = nil
		begin
			raise ToolException.new "only deserialization from byte-array is supported" if raw.class != Array
			if @is_array
				expected_array_length = @size * array_depth
				raise ToolException.new "byte-array length (#{raw.length}) and expected byte-array length (#{expected_array_length}) mismatch for variable '#{@name}'" if raw.length != expected_array_length
				read_value = @type.downcase == 'char' ? "" : []
				index = 0
				each_element_size = @size
				end_index = each_element_size - 1
				
				while index < raw.length
					element = parse_value raw[index..end_index]
					if element.class == String
						read_value += element 
					else
						read_value.push element
					end
					index     += each_element_size
					end_index += each_element_size
				end

				read_value.flatten! if read_value.class == Array
			else
				read_value = parse_value raw
			end
		rescue ToolException => ex
			raise ToolException.new "variable.deserialize: " + ex.message
		end
		return read_value
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

	def parse_value(raw)
		read_value = nil
		case @type.downcase
			when "bool"
				read_value = parse_value_from_raw(raw, 1) == 1
			when "char"
				read_value = parse_value_from_raw(raw, 1).chr
			when /(u|h|i|s|c)[1-9]{1,2}/i   # integers
				read_value = parse_value_from_raw(raw, @size)
			else raise ToolException.new "cannot deserialize passed byte-stream into variable '#{@name}' of type '#{@type}'; type not supported"
		end
		return read_value
	end

	def parse_value_from_raw(raw, size_expected)
		raise ToolException.new "variable instance not present in memory ('#{@name}')" if raw.length == 0
		raise ToolException.new "byte-array size ('#{raw.length}') does not match the expected size ('#{size_expected}') for variable '#{@name}'" unless raw.length == size_expected
		raw.each {  |b| raise ToolException.new "variable instance not present in memory ('#{@name}')" if b == nil }
		i = 0
		value = 0
		raw.reverse! if @@little_endian
		size_expected.times {
			value |= raw[i]
			value <<= 8
			i += 1
		}
		value >>= 8
		return value
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
