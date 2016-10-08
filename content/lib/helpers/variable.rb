
class Variable
	attr_accessor :name, :size, :type, :address, :value

	def initialize(name, size, type, address, value)
		@name    = name
		@size    = size
		@type    = type
		@address = address
		@value   = value
	end

	def ==(obj)
		return ( @name    == obj.name &&
		         @size    == size &&
		         @type    == type &&
		         @address == address &&
		         @value   == value )
	end
end
