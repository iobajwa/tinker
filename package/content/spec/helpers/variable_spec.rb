
require "spec_helper"
require "helpers/variable"

describe Variable do
	describe "when parsing variable from raw data" do
		describe "should raise exception when" do
			it "compelte metadata is missing" do
				expect { Variable.parse(:a, nil) }.to raise_exception(ToolException, "Variable.parse: metadata missing for 'a' variable" )
			end
			it "memory_name is missing" do
				expect { Variable.parse :a, { :size => 2, :type => 'u16', :address => 0, :value => 230 } }.to raise_exception(ToolException, "Variable.parse: memory_name missing for 'a' variable" )
			end
			it "size is missing" do
				expect { Variable.parse :a, { :type => 'u16', :address => 0, :value => 230, :memory_name => "flash" } }.to raise_exception(ToolException, "Variable.parse: size missing for 'a' variable" )
			end
			it "size is non-integer" do
				expect { Variable.parse :var, { :size => '2', :type => 'u16', :address => 0, :value => 230, :memory_name => "flash" } }.to raise_exception(ToolException, "Variable.parse: size must be a number for 'var' variable" )
			end
			it "size less than 1" do
				expect { Variable.parse :v, { :size => 0, :type => 'u16', :address => 0, :value => 230, :memory_name => "flash" } }.to raise_exception(ToolException, "Variable.parse: size cannot be less than 1 for 'v' variable" )
			end
			it "type is missing" do
				expect { Variable.parse :v, { :size => 1, :address => 0, :value => 230, :memory_name => "flash" } }.to raise_exception(ToolException, "Variable.parse: type missing for 'v' variable" )
			end
			it "type is non-string" do
				expect { Variable.parse :v, { :size => 1, :type => 23, :address => 0, :value => 230, :memory_name => "flash" } }.to raise_exception(ToolException, "Variable.parse: type must be a string for 'v' variable" )
			end
			it "address is missing" do
				expect { Variable.parse :v, { :size => 1, :type => 't', :value => 230, :memory_name => "flash" } }.to raise_exception(ToolException, "Variable.parse: address missing for 'v' variable" )
			end
			it "address is non-integer" do
				expect { Variable.parse :vaa, { :size => 1, :type => 't', :address => 'val', :value => 230, :memory_name => "flash" } }.to raise_exception(ToolException, "Variable.parse: address must be a number for 'vaa' variable" )
			end
			it "address less than 0" do
				expect { Variable.parse :v, { :size => 1, :type => 't', :address => -1, :value => 230, :memory_name => "flash" } }.to raise_exception(ToolException, "Variable.parse: address cannot be negative for 'v' variable" )
			end
			it "value is missing" do
				expect { Variable.parse :v, { :size => 1, :type => 't', :address => -1, :memory_name => "flash" } }.to raise_exception(ToolException, "Variable.parse: value missing for 'v' variable" )
			end
		end

		it "returns an instance of Variable with correctly populated properties" do
			expected_var = Variable.new "volts", 2, 'u16', 0, 230, "eeprom"

			var = Variable.parse "volts", { :size => 2, :type => 'u16', :address => 0, :value => 230, :memory_name => 'eeprom' }

			var.should be == expected_var
		end
	end

	describe "when serializing value to byte-stream" do
		before(:each) do
			$var = Variable.new "var", 2, "u16", 0, 23, "flash"
		end
		describe "raises exception when" do
			describe "value is non-array and" do
				it "value type is bool and value is neither true nor false" do
					$var.type = "bool"
					$var.size = 1
					expect { $var.serialize 23 }.to raise_exception(ToolException, "variable.serialize: invalid value '23' for variable 'var' of type 'bool'")
				end
				it "value is of unknown-type" do
					$var.type = "unknown"
					expect { $var.serialize 23 }.to raise_exception(ToolException, "variable.serialize: cannot serialize variable 'var' of type 'unknown'")
				end
			end

			describe "value is array and" do
				before(:each) do
					$var.is_array = true
					$var.array_depth = 2
				end
				it "array_depth is less than 1" do
					$var.array_depth = 0
					expect { $var.serialize 2 }. to raise_exception(ToolException, "variable.serialize: cannot serialize variable 'var' because array_depth < 1")
				end
				it "value type is bool and value is neither true nor false" do
					$var.type = "bool"
					$var.size = 1
					expect { $var.serialize 23 }.to raise_exception(ToolException, "variable.serialize: invalid value '23' at index 1 for variable 'var' of type 'bool'")
				end
				it "passed array length is > array_depth" do
					expect { $var.serialize [23, 23, 23] }.to raise_exception(ToolException, "variable.serialize: cannot serialize variable 'var' because passed array value.length != array_depth")
				end
			end
		end

		describe "returns correct data when" do
			describe "value is non-array and is of" do
				it "bool type" do
					$var.type = "bool"
					$var.size = 1
					$var.serialize(true).should be == [1]
					$var.serialize(false).should be == [0]
				end
				it "integer type" do
					$var.serialize(1).should be == [1, 0]
					$var.size = 4
					$var.serialize(0x87654321).should be == [0x21, 0x43, 0x65, 0x87]
					$var.size = 6
					$var.serialize(0x123487654321).should be == [0x21, 0x43, 0x65, 0x87, 0x34, 0x12]
				end
				it "Char type" do
					$var.type = "Char"
					$var.size = 1
					$var.serialize("S").should be == [83]
				end
			end

			describe "value is an array and is of" do
				before(:each) do
					$var.is_array = true
					$var.array_depth = 4
				end
				it "bool type" do
					$var.type = "bool"
					$var.size = 4

					$var.serialize(false).should be == [0, 0, 0, 0]
					$var.serialize(true).should be == [1, 1, 1, 1]
					$var.serialize([true, false, false, true]).should be == [1, 0, 0, 1]
				end
				it "integer type" do
					$var.size = 2
					$var.serialize(12).should be == [12, 0, 12, 0, 12, 0, 12, 0]
					$var.serialize([0x12, 0x1234, 0x34, 0x1200]).should be == [0x12, 0, 0x34, 0x12, 0x34, 0, 0, 0x12]
				end
				it "Char type" do
					$var.type = "Char"
					$var.array_depth = 6
					$var.serialize('s').should be == [115, 0, 0, 0, 0, 0]
					$var.serialize('sat').should be == [115, 97, 116, 0, 0, 0]
				end
			end

			describe "value is nil and" do
				it "is non array" do
					$var.size = 2
					$var.serialize(nil).should be == [nil, nil]
				end
				it "is array" do
					$var.size = 2
					$var.is_array = true
					$var.array_depth = 3
					$var.serialize(nil).should be == [nil, nil, nil, nil, nil, nil]
				end
			end
		end
	end

	describe "when deserializing byte-stream to composite value" do
		before(:each) do
			$var = Variable.new "var", 2, "u16", 0, 23, "flash"
		end
		describe "raises exception when" do
			describe "variable is array and" do
				it "array depth and passed byte stream length do not match" do
					$var.type = "bool"
					$var.size = 1
					$var.is_array = true
					$var.array_depth = 4

					expect { $var.deserialize [1] }.to raise_exception(ToolException, "variable.deserialize: byte-array length (1) and expected byte-array length (4) mismatch for variable 'var'")
				end
			end
			it "passed data-stream is empty" do
				expect { $var.deserialize [] }.to raise_exception(ToolException, "variable.deserialize: variable instance not present in memory ('var')")
			end
			it "passed data-stream length does not match expected size" do
				expect { $var.deserialize [1] }.to raise_exception(ToolException, "variable.deserialize: byte-array size ('1') does not match the expected size ('2') for variable 'var'")
			end
		end
		describe "and variable is non-array, returns correctly formed data when" do
			it "variable type is bool" do
				$var.type = "bool"
				$var.size = 1

				$var.deserialize([0]).should be == false
				$var.deserialize([1]).should be == true
			end
			it "variable type is integer" do
				$var.size = 2

				$var.deserialize([0x34, 0x12]).should be == 0x1234
			end
			it "variable type is Char" do
				$var.size = 1
				$var.type = "Char"

				$var.deserialize([0x34]).should be == '4'
			end
			it "passed data-stream contains nil elements" do
				$var.deserialize([1, nil]).should be_nil
			end
		end
		describe "and variable is array, returns correctly formed data when" do
			before(:each) do
				$var.is_array = true
				$var.array_depth = 5
			end
			it "variable type is bool" do
				$var.type = "bool"
				$var.size = 1

				$var.deserialize([0, 1, 0, 1, 1]).should be == [false, true, false, true, true]
			end
			it "variable type is integer" do
				$var.array_depth = 2
				
				$var.deserialize([0x12, 0, 0, 0x12]).should be == [0x12, 0x1200]
			end
			it "variable type is Char" do
				$var.type = "Char"
				$var.size = 1

				$var.deserialize([0x30, 0x31, 0x32, 0x33, 0x34]).should be == '01234'
			end
		end
	end
end
