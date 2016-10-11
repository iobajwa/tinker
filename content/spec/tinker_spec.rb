
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
			dummy_var      = $tinker.variables[1]
			dummy_memories = { 1 => 2}
			dummy_memory   = { 3 => 4 }
			expect($tinker).to receive(:get_variable).with("v").and_return(dummy_var)
			expect($dummy_cpu).to receive(:memories).and_return(dummy_memories)
			expect(dummy_memories).to receive(:[]).with("flash").and_return(dummy_memory)
			expect(dummy_memory).to receive(:read_object).with( 0, 2 ).and_return('result')
			expect(dummy_var).to receive(:deserialize).with("result").and_return(["result"])
			
			$tinker["v"].should be == ['result']
		end
		it "should raise exception with description when underlying call failed with an exception" do
			expect($tinker).to receive(:get_variable).with("v").and_return($tinker.variables[1])
			expect($dummy_cpu).to receive(:memories).and_raise(ToolException, "blah blah blah")

			expect { $tinker["v"] }.to raise_exception(ToolException, "Tinker: error reading variable 'amps': blah blah blah")
		end
	end

	describe "when writing variable value using index" do
		it "should delgate work to cpu with proper information" do
			dummy_var = $tinker.variables[1]
			dummy_memories = { 1 => 2}
			dummy_memory   = { 3 => 4 }
			expect($tinker).to receive(:get_variable).with("v").and_return(dummy_var)
			expect(dummy_var).to receive(:serialize).with(12).and_return([12])
			expect($dummy_cpu).to receive(:memories).and_return(dummy_memories)
			expect(dummy_memories).to receive(:[]).with("flash").and_return(dummy_memory)
			expect(dummy_memory).to receive(:write_object).with([12], 0)
			
			$tinker["v"] = 12
		end
		it "should raise exception with description when underlying call failed with an exception" do
			expect($tinker).to receive(:get_variable).with("v").and_return($tinker.variables[1])
			expect($dummy_cpu).to receive(:memories).and_raise(ToolException, "blah blah blah")

			expect { $tinker["v"] = 12 }.to raise_exception(ToolException, "Tinker: error writing variable 'amps': blah blah blah")
		end
	end


	describe "when loading image" do
		describe "should raise exception when" do
			it "hex_file does not exists" do
				expect(File).to receive(:exists?).with('hex').and_return(false)
				expect { Tinker.load_image 'hex', 'meta.file' }.to raise_exception(ToolException, "Tinker: hex file ('hex') does not exists")
			end
			it "meta_file does not exists" do
				expect(File).to receive(:exists?).with('hex').and_return(true)
				expect(File).to receive(:exists?).with('meta.file').and_return(false)
				expect { Tinker.load_image 'hex', 'meta.file' }.to raise_exception(ToolException, "Tinker: meta file ('meta.file') does not exists")
			end
		end
		it "returns a tinker instance when a meta_file is provided" do
			dummy_data = { 1 => 2, 3 => 4 }
			dummy_hex_lines = ['one', 'two']
			dummy_tinker_object = {}
			expect(File).to receive(:exists?).with('hex').and_return(true)
			expect(File).to receive(:exists?).with('meta.file').and_return(true)
			expect(YAML).to receive(:load_file).with('meta.file').and_return({:meta => { :cpu => 'cpu', :data => dummy_data } })
			expect(Variable).to receive(:parse).with(1, 2).and_return('var 1')
			expect(Variable).to receive(:parse).with(3, 4).and_return('var 2')
			expect(File).to receive(:readlines).with('hex').and_return(dummy_hex_lines)
			expect(Tinker).to receive(:new).and_return(dummy_tinker_object)
			expect(CPU).to receive(:parse).with('cpu').and_return('cpu.object')
			expect(dummy_tinker_object).to receive(:cpu=).with('cpu.object')
			expect(dummy_tinker_object).to receive(:variables=).with(['var 1', 'var 2'])
			expect(dummy_tinker_object).to receive(:raw_hex_image=).with(dummy_hex_lines)
			expect(dummy_tinker_object).to receive(:hex_file=).with('hex')
			expect(dummy_tinker_object).to receive(:meta_file=).with('meta.file')
			dummy_cpu = {}
			expect(dummy_tinker_object).to receive(:cpu).and_return(dummy_cpu)
			expect(dummy_cpu).to receive(:mount_hex).with(dummy_hex_lines)

			Tinker.load_image('hex', 'meta.file').should be == dummy_tinker_object
		end
		it "returns a tinker instance when a cpu name is provided" do
			dummy_data = { 1 => 2, 3 => 4 }
			dummy_hex_lines = ['one', 'two']
			dummy_tinker_object = {}
			expect(File).to receive(:exists?).with('hex').and_return(true)
			expect(File).to receive(:readlines).with('hex').and_return(dummy_hex_lines)
			expect(Tinker).to receive(:new).and_return(dummy_tinker_object)
			expect(CPU).to receive(:parse).with('cpu').and_return('cpu.object')
			expect(dummy_tinker_object).to receive(:cpu=).with('cpu.object')
			expect(dummy_tinker_object).to receive(:variables=).with([])
			expect(dummy_tinker_object).to receive(:raw_hex_image=).with(dummy_hex_lines)
			expect(dummy_tinker_object).to receive(:hex_file=).with('hex')
			dummy_cpu = {}
			expect(dummy_tinker_object).to receive(:cpu).and_return(dummy_cpu)
			expect(dummy_cpu).to receive(:mount_hex).with(dummy_hex_lines)

			Tinker.load_image('hex', 'cpu').should be == dummy_tinker_object
		end
		it "returns a tinker instance when hash as meta_file is provided" do
			dummy_data = { 1 => 2, 3 => 4 }
			dummy_hex_lines = ['one', 'two']
			dummy_tinker_object = {}
			expect(File).to receive(:exists?).with('hex').and_return(true)
			expect(Variable).to receive(:parse).with(1, 2).and_return('var 1')
			expect(Variable).to receive(:parse).with(3, 4).and_return('var 2')
			expect(File).to receive(:readlines).with('hex').and_return(dummy_hex_lines)
			expect(Tinker).to receive(:new).and_return(dummy_tinker_object)
			expect(CPU).to receive(:parse).with('cpu').and_return('cpu.object')
			expect(dummy_tinker_object).to receive(:cpu=).with('cpu.object')
			expect(dummy_tinker_object).to receive(:variables=).with(['var 1', 'var 2'])
			expect(dummy_tinker_object).to receive(:raw_hex_image=).with(dummy_hex_lines)
			expect(dummy_tinker_object).to receive(:hex_file=).with('hex')
			dummy_cpu = {}
			expect(dummy_tinker_object).to receive(:cpu).and_return(dummy_cpu)
			expect(dummy_cpu).to receive(:mount_hex).with(dummy_hex_lines)

			Tinker.load_image('hex', {:meta => { :cpu => 'cpu', :data => dummy_data } }).should be == dummy_tinker_object
		end
	end

	it "when writing default values of variables, writes values of each variable" do
		a = []
		b = []
		expect($tinker).to receive(:variables).and_return([a, b])
		expect(a).to receive(:default_value).and_return('1')
		expect(b).to receive(:default_value).and_return('2')
		expect($tinker).to receive(:write_value_object).with(a, '1')
		expect($tinker).to receive(:write_value_object).with(b, '2')

		$tinker.write_default_values
	end

	describe "when dumping loaded image to a file" do
		it "creates valid file contents" do
			expect($dummy_cpu).to receive(:dump_hex).and_return("lines")
			dummy_file = double("dummy file").as_null_object
			expect(dummy_file).to receive(:puts).with("lines")
			expect(dummy_file).to receive(:close)
			expect(File).to receive(:new).with("blah", "w").and_return(dummy_file)

			$tinker.dump "blah"
		end

		it "makes sure the file is closed when an exception is encountered" do
			expect($dummy_cpu).to receive(:dump_hex).and_return("lines")
			expect(File).to receive(:new).with("blah", "w").and_raise("blaah")

			expect { $tinker.dump "blah" }.to raise_exception("blaah")
		end
	end
end
