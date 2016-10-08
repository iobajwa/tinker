
require "spec_helper"
require "tinker"
require "helpers/tool_messages"
require "helpers/variable"

describe Tinker do
	before(:each) do
		$tinker = Tinker.new
		$tinker.variables = [ Variable.new("volts", 2, 'u16', 0, 230, "eeprom"), 
		                     Variable.new("amps", 2, 'u16', 0, 10, "flash"), ]
		$dummy_cpu = []
		$tinker.cpu = $dummy_cpu
	end
	
	describe "when obtaining a variable instance" do
		it "should raise exception when no matching variable is found" do
			expect { $tinker.get_variable "blah" }.to raise_exception(ToolException, "Tinker: variable not found ('blah')" )
		end
		it "should return the matching instance otherwise" do
			$tinker.get_variable("AMPS").should be == $tinker.variables[1]
		end
	end

	describe "when reading variable value using index" do
		it "should return correct value as read from cpu" do
			dummy_var = $tinker.variables[1]
			expect($tinker).to receive(:get_variable).with("v").and_return(dummy_var)
			expect($dummy_cpu).to receive(:read_memory).with("flash", 0, 2).and_return('result')
			expect(dummy_var).to receive(:deserialize).with("result").and_return(["result"])
			
			$tinker["v"].should be == ['result']
		end
		it "should raise exception with description when underlying call failed with an exception" do
			expect($tinker).to receive(:get_variable).with("v").and_return($tinker.variables[1])
			expect($dummy_cpu).to receive(:read_memory).and_raise(ToolException, "blah blah blah")

			expect { $tinker["v"] }.to raise_exception(ToolException, "Tinker: error reading variable 'amps': blah blah blah")
		end
	end

	describe "when writing variable value using index" do
		it "should delgate work to cpu with proper information" do
			dummy_var = $tinker.variables[1]
			expect($tinker).to receive(:get_variable).with("v").and_return(dummy_var)
			expect(dummy_var).to receive(:serialize).with(12).and_return([12])
			expect($dummy_cpu).to receive(:write_memory).with("flash", 0, 2, [12])
			
			$tinker["v"] = 12
		end
		it "should raise exception with description when underlying call failed with an exception" do
			expect($tinker).to receive(:get_variable).with("v").and_return($tinker.variables[1])
			expect($dummy_cpu).to receive(:write_memory).and_raise(ToolException, "blah blah blah")

			expect { $tinker["v"] = 12 }.to raise_exception(ToolException, "Tinker: error writing variable 'amps': blah blah blah")
		end
	end


	describe "when loading image" do
		describe "should raise exception when" do
			it "hex_file does not exists" do
				expect(File).to receive(:exists?).with('hex').and_return(false)
				expect { Tinker.load_image 'hex', 'meta' }.to raise_exception(ToolException, "Tinker: hex file ('hex') does not exists")
			end
			it "meta_file does not exists" do
				expect(File).to receive(:exists?).with('hex').and_return(true)
				expect(File).to receive(:exists?).with('meta').and_return(false)
				expect { Tinker.load_image 'hex', 'meta' }.to raise_exception(ToolException, "Tinker: meta file ('meta') does not exists")
			end
		end
		it "returns a tinker instance otherwise" do
			dummy_data = { 1 => 2, 3 => 4 }
			dummy_hex_lines = ['one', 'two']
			dummy_tinker_object = {}
			expect(File).to receive(:exists?).with('hex').and_return(true)
			expect(File).to receive(:exists?).with('meta').and_return(true)
			expect(YAML).to receive(:load_file).with('meta').and_return({:meta => { :cpu => 'cpu', :data => dummy_data } })
			expect(Variable).to receive(:parse).with(1, 2).and_return('var 1')
			expect(Variable).to receive(:parse).with(3, 4).and_return('var 2')
			expect(File).to receive(:readlines).with('hex').and_return(dummy_hex_lines)
			expect(Tinker).to receive(:new).and_return(dummy_tinker_object)
			expect(CPU).to receive(:parse).with('cpu').and_return('cpu.object')
			expect(dummy_tinker_object).to receive(:cpu=).with('cpu.object')
			expect(dummy_tinker_object).to receive(:variables=).with(['var 1', 'var 2'])
			expect(dummy_tinker_object).to receive(:raw_hex_image=).with(dummy_hex_lines)
			expect(dummy_tinker_object).to receive(:hex_file=).with('hex')
			expect(dummy_tinker_object).to receive(:meta_file=).with('meta')
			dummy_cpu = {}
			expect(dummy_tinker_object).to receive(:cpu).and_return(dummy_cpu)
			expect(dummy_cpu).to receive(:mount_hex).with(dummy_hex_lines)

			Tinker.load_image('hex', 'meta').should be == dummy_tinker_object
		end
	end
end
