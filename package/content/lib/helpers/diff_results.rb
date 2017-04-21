
class DiffResult
	attr_accessor :memory_name, :memory_size, :diff_type, :base_name

	def initialize(memory_name, memory_size, diff_type)
		@memory_name = memory_name
		@memory_size = memory_size
		@diff_type   = diff_type
		@base_name   = 'base'
	end

	def hex_to_s(value, digits=4)
		return value == nil ? '' : sprintf("0x%0#{digits}X", value)
	end
end

class MemoryDiff < DiffResult
	def initialize(memory_name, memory_size, diff_type)
		super(memory_name, memory_size, diff_type)
	end

	def MemoryDiff.valid_hit?(memory_name, memory_size, base_memory, other_memory)
		return nil if base_memory != nil && other_memory != nil
		return nil if base_memory == nil && other_memory == nil

		diff_type = other_memory == nil ? '-' : '+'
		return MemoryDiff.new memory_name, memory_size, diff_type
	end

	def to_s
		return "#{@diff_type} #{@memory_name.to_s} (#{@memory_size} bytes)"
	end
end

class MemoryCellDiff < DiffResult
	attr_accessor :memory_address, :base_value, :other_value

	def initialize(memory_name, memory_size, diff_type, memory_address, base_value, other_value)
		super(memory_name, memory_size, diff_type)
		@memory_address = memory_address
		@base_value     = base_value
		@other_value    = other_value
	end

	def MemoryCellDiff.valid_hit?(memory_name, memory_size, memory_address, base_value, other_value)
		return nil if other_value == base_value
		if other_value != nil && base_value != nil
			diff_type = "~"
		else
			diff_type = other_value == nil ? '-' : '+'
		end
		MemoryCellDiff.new memory_name, memory_size, diff_type, memory_address, base_value, other_value
	end

	def to_s
		result = "#{@diff_type} #{@memory_name} @ #{hex_to_s @memory_address} : "
		case diff_type
			when "+"
				result += "'#{hex_to_s @other_value, 2}'"
			when "-"
				result += "'#{hex_to_s @base_value, 2}'"
			when "~"
				result += "'#{hex_to_s @other_value, 2}' (#{@base_name} is '#{hex_to_s @base_value, 2}')"
		end
		return result
	end
end
