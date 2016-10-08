
require "spec_helper"
require "helpers/symbol_manager"
require "helpers/tool_messages"
require "helpers/variable"

describe SymbolManager do
	describe "when parsing the symbols from raw data" do
		describe "should raise exception when" do
			it "size is missing" do
				dummy = { :a => { :type => 'u16', :address => 0, :value => 230 } }
				expect { SymbolManager.parse dummy }.to raise_exception(ToolException, "SymbolManager.parse: size missing for 'a' variable" )
			end
			it "size is non-integer" do
				dummy = { :var => { :size => '2', :type => 'u16', :address => 0, :value => 230 } }
				expect { SymbolManager.parse dummy }.to raise_exception(ToolException, "SymbolManager.parse: size must be a number for 'var' variable" )
			end
			it "size less than 1" do
				dummy = { :v => { :size => 0, :type => 'u16', :address => 0, :value => 230 } }
				expect { SymbolManager.parse dummy }.to raise_exception(ToolException, "SymbolManager.parse: size cannot be less than 1 for 'v' variable" )
			end
			it "type is missing" do
				dummy = { :v => { :size => 1, :address => 0, :value => 230 } }
				expect { SymbolManager.parse dummy }.to raise_exception(ToolException, "SymbolManager.parse: type missing for 'v' variable" )
			end
			it "type is non-string" do
				dummy = { :v => { :size => 1, :type => 23, :address => 0, :value => 230 } }
				expect { SymbolManager.parse dummy }.to raise_exception(ToolException, "SymbolManager.parse: type must be a string for 'v' variable" )
			end
			it "address is missing" do
				dummy = { :v => { :size => 1, :type => 't', :value => 230 } }
				expect { SymbolManager.parse dummy }.to raise_exception(ToolException, "SymbolManager.parse: address missing for 'v' variable" )
			end
			it "address is non-integer" do
				dummy = { :vaa => { :size => 1, :type => 't', :address => 'val', :value => 230 } }
				expect { SymbolManager.parse dummy }.to raise_exception(ToolException, "SymbolManager.parse: address must be a number for 'vaa' variable" )
			end
			it "address less than 0" do
				dummy = { :v => { :size => 1, :type => 't', :address => -1, :value => 230 } }
				expect { SymbolManager.parse dummy }.to raise_exception(ToolException, "SymbolManager.parse: address cannot be negative for 'v' variable" )
			end
			it "value is missing" do
				dummy = { :v => { :size => 1, :type => 't', :address => -1 } }
				expect { SymbolManager.parse dummy }.to raise_exception(ToolException, "SymbolManager.parse: value missing for 'v' variable" )
			end
		end

		it "returns an instances of SymbolManager with correctly populated symbols " do
			dummy_symbols = { :volts => { 
			                    :size => 2, :type => 'u16', :address => 0, :value => 230 
			                    },
			                  :amps => {
			                  	:size => 2, :type => 'u16', :address => 0, :value => 10
		                        },
			                }
			expected_symbols = [
			                       Variable.new("volts", 2, 'u16', 0, 230), 
			                       Variable.new("amps", 2, 'u16', 0, 10), 
			                   ]

			sm = SymbolManager.parse dummy_symbols

			sm.symbols.should be == expected_symbols
		end
	end

	describe "when fetching variable instance using indexing" do
		before(:each) do
			$dummy_vars = [ Variable.new("volts", 2, 'u16', 0, 230), Variable.new("amps", 2, 'u16', 0, 10) ]
			$manager = SymbolManager.new $dummy_vars
		end

		it "returns nil when no matching variable is found" do
			$manager["blah"].should be == nil
		end

		it "returns the named variable instance when a match is found" do
			$manager["AMPS"].should be == $dummy_vars[1]
		end
	end
end
