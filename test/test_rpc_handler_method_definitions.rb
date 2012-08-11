require 'helper'

class TesRpcHandlerMethodDefinitions < Test::Unit::TestCase
  
  class Sub < BlogRPC::BasicHandler
    rpc "julik.testMethod", :in => [:int], :out => :array do
      []
    end
  end
  
  class SubSub < Sub
    rpc "julik.anotherMethod", :in => [:int, :struct], :out => :array do
      []
    end
  end
  
  def test_methods_propagated_on_inheritance_chain
    basics = BlogRPC::BasicHandler.rpc_methods_and_signatures
    only_supported = {"supported_methods" => ["mt.supportedMethods", "array supportedMethods()"] }
    assert_equal only_supported, basics
  end
  
  def test_methods_on_inherited_class_included_into_table
    all_rpc_methods = Sub.rpc_methods_and_signatures
    spliced_from_two_classes = {
      "supported_methods" => ["mt.supportedMethods", "array supportedMethods()"],
      "test_method"=>["julik.testMethod", "array testMethod(int)"]
    }
    assert_equal spliced_from_two_classes, all_rpc_methods
  end
  
  def test_methods_on_inherited_sub_sub_class_included_into_table
    all_rpc_methods = SubSub.rpc_methods_and_signatures
    spliced_from_two_classes = {
      "supported_methods" => ["mt.supportedMethods", "array supportedMethods()"],
      "test_method" => ["julik.testMethod", "array testMethod(int)"],
      "another_method" => ["julik.anotherMethod", "array anotherMethod(int, struct)"]
    }
    assert_equal spliced_from_two_classes, all_rpc_methods
  end
  
  def test_method_introspection_called_by_xmlrpc
    sub = SubSub.new
    method_table = sub.get_methods(nil, '.')
    assert_equal 3, method_table.length, "The method table should include 3 method signatures"
    first_method = method_table[0]
    assert_equal "julik.anotherMethod", first_method[0], "The first item in the method description should be a namespaced name"
    assert_kind_of Proc, first_method[1], "The second item should be the proc handling the call"
    assert_equal 'array anotherMethod(int, struct)', first_method[2], "The last item should a C-like method signature with types"
  end
end
