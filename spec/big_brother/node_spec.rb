require 'spec_helper'

describe BigBrother::Node do
  describe "#invalidate_weight!" do
    it "sets the weight to zero" do
      node = Factory.node(:address => '127.0.0.1', :weight => 90)
      node.invalidate_weight!

      node.weight.should be_zero
    end
  end

  describe "#initialize_weight!" do
    it "sets the weight to the node class' initial weight value" do
      node = Factory.node(:address => '127.0.0.1', :weight => 90)
      node.initialize_weight!

      node.weight.should == BigBrother::Node::INITIAL_WEIGHT
    end
  end

  describe "#monitor" do
    it "a node's health should increase linearly over the specified ramp up time" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(100)
      Time.stub(:now).and_return(1345043600)

      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:ramp_up_time => 60, :fwmark => 100, :nodes => [node])

      Time.stub(:now).and_return(1345043630)
      node.monitor(cluster).should == 50

      Time.stub(:now).and_return(1345043645)
      node.monitor(cluster).should == 75

      Time.stub(:now).and_return(1345043720)
      node.monitor(cluster).should == 100
    end

    it "sets the weight to 100 for each node if an up file exists" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1', :weight => 10)
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])

      BigBrother::StatusFile.new('up', 'test').create('Up for testing')

      node.monitor(cluster).should == 100
    end

    it "sets the weight to 0 for each node if a down file exists" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(56)
      node = Factory.node(:address => '127.0.0.1')
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])

      BigBrother::StatusFile.new('down', 'test').create('Down for testing')

      node.monitor(cluster).should == 0
    end

    it "caps the weight of a node to the max_weight configured" do
      BigBrother::HealthFetcher.stub(:current_health).and_return(100)
      node = Factory.node(:address => '127.0.0.1', :max_weight => 10)
      cluster = Factory.cluster(:fwmark => 100, :nodes => [node])

      node.monitor(cluster).should == 10
    end
  end

  describe "#==" do
    it "is true when two nodes have the same address and port" do
      node1 = Factory.node(:address => "127.0.0.1", :port => "8000")
      node2 = Factory.node(:address => "127.0.0.1", :port => "8001")
      node1.should_not == node2

      node2 = Factory.node(:address => "127.0.0.2", :port => "8000")
      node1.should_not == node2

      node2 = Factory.node(:address => "127.0.0.1", :port => "8000")
      node1.should == node2
    end
  end

  describe "<=>" do
    it "returns 1 when compared to a node with a nil weight" do
      node1 = Factory.node(:address => "127.0.0.1", :port => "8000", :priority => 1, :weight => 0)
      node2 = Factory.node(:address => "127.0.0.2", :port => "8000", :priority => 2, :weight => nil)
      (node1 <=> node2).should == 1
    end

    it "returns 1 for comparison of an unhealthy node to an healthy one" do
      node1 = Factory.node(:address => "127.0.0.1", :port => "8000", :priority => 1, :weight => 0)
      node2 = Factory.node(:address => "127.0.0.2", :port => "8000", :priority => 2, :weight => 90)
      (node1 <=> node2).should == 1
    end

    it "returns -1 for a node with lower priority" do
      node1 = Factory.node(:address => "127.0.0.1", :port => "8000", :priority => 1)
      node2 = Factory.node(:address => "127.0.0.2", :port => "8000", :priority => 2)
      (node1 <=> node2).should == -1
    end

    it "returns 1 for a node with higher priority" do
      node1 = Factory.node(:address => "127.0.0.1", :port => "8000", :priority => 1)
      node2 = Factory.node(:address => "127.0.0.2", :port => "8000", :priority => 2)
      (node2 <=> node1).should == 1
    end

    it "uses ip address for comparison if the priorities are the same" do
      node1 = Factory.node(:address => "127.0.0.1", :port => "8000", :priority => 1)
      node2 = Factory.node(:address => "127.0.0.2", :port => "8000", :priority => 1)
      (node2 <=> node1).should == 1
      (node1 <=> node2).should == -1
    end
  end

  describe "age" do
    it "is the time in seconds since the node started" do
      Time.stub(:now).and_return(1345043612)
      node = Factory.node(:address => "127.0.0.1")

      node.age.should == 0
    end
  end

  describe "incorporate_state" do
    it "takes the weight and the start time from the other node, but leaves rest of config" do
      original_start_time = Time.now
      node_with_state = Factory.node(:path => '/old/path', :start_time => original_start_time, :weight => 65)
      node_from_config = Factory.node(:path => '/new/path', :start_time => Time.now, :weight => 100)

      node_from_config.incorporate_state(node_with_state)

      node_from_config.path.should == '/new/path'
      node_from_config.start_time.should == original_start_time
      node_from_config.weight.should == 65
    end
  end
end
