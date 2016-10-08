
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
end
