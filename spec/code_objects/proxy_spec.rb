require File.dirname(__FILE__) + '/spec_helper'

describe YARD::CodeObjects::Proxy do
  before { Registry.clear }

  it "should return the object if it's in the Registry" do
    pathobj = ModuleObject.new(:root, :YARD)
    proxyobj = P(:root, :YARD)
    proxyobj.type.should == :module
    Proxy.should_not === proxyobj
  end

  it "should handle complex string namespaces" do
    ModuleObject.new(:root, :A)
    pathobj = ModuleObject.new(P(nil, :A), :B)
    P(:root, "A::B").should be_instance_of(ModuleObject)
  end

  it "should not return true to Proxy === obj if obj is a Proxy class holding a resolved object" do
    Proxy.should === P(:root, 'a')
    Proxy.should_not === P(:root)
    MethodObject.new(:root, 'a')
    Proxy.should_not === P(:root, 'a')
    x = Proxy.new(:root, 'a')
    Proxy.should_not === x
  end

  it "should return the object if it's an included Module" do
    yardobj = ModuleObject.new(:root, :YARD)
    pathobj = ClassObject.new(:root, :TestClass)
    pathobj.instance_mixins << yardobj
    P(P(nil, :TestClass), :YARD).should be_instance_of(ModuleObject)
  end

  it "should respond_to respond_to?" do
    obj = ClassObject.new(:root, :Object)
    yardobj = ModuleObject.new(:root, :YARD)
    P(:YARD).respond_to?(:children).should == true
    P(:NOTYARD).respond_to?(:children).should == false

    P(:YARD).respond_to?(:initialize).should == false
    P(:YARD).respond_to?(:initialize, true).should == true
    P(:NOTYARD).respond_to?(:initialize).should == false
    P(:NOTYARD).respond_to?(:initialize, true).should == true
  end

  it "should make itself obvious that it's a proxy" do
    pathobj = P(:root, :YARD)
    pathobj.class.should == Proxy
    (Proxy === pathobj).should == true
  end

  it "should pretend it's the object's type if it can resolve" do
    pathobj = ModuleObject.new(:root, :YARD)
    proxyobj = P(:root, :YARD)
    proxyobj.should be_instance_of(ModuleObject)
  end

  it "should handle instance method names" do
    obj = P(nil, '#test')
    obj.name.should == :test
    obj.path.should == "#test"
    obj.namespace.should == Registry.root
  end

  it "should handle instance method names under a namespace" do
    pathobj = ModuleObject.new(:root, :YARD)
    obj = P(pathobj, "A::B#test")
    obj.name.should == :test
    obj.path.should == "A::B#test"
  end

  it "should allow type to be changed" do
    obj = P("InvalidClass")
    obj.type.should == :proxy
    Proxy.should === obj
    obj.type = :class
    obj.type.should == :class
  end

  it "should NOT retain a type change between Proxy objects" do
    P("InvalidClass").type = :class
    P("InvalidClass").type.should == :proxy
  end

  it "should use type to ensure resolved object is of intended type" do
    YARD.parse_string <<-eof
      module Foo
        class Bar; end
        def self.Bar; end
      end
    eof
    proxy = Proxy.new(P('Foo'), 'Bar')
    proxy.type = :method
    proxy.path.should == 'Foo.Bar'
  end

  it "should allow type in initializer" do
    Proxy.new(Registry.root, 'Foo', :method).type.should == :method
    P(Registry.root, 'Foo', :method).type.should == :method
  end

  it "should never equal Registry.root" do
    P("MYPROXY").should_not == Registry.root
    P("X::A").should_not == Registry.root
  end

  it "should reset namespace and name when object is resolved" do
    obj1 = ModuleObject.new(:root, :YARD)
    obj2 = ModuleObject.new(:root, :NOTYARD)
    resolved = Proxy.new(obj2, :YARD)
    resolved.should == obj1
    resolved.namespace.should == Registry.root
    resolved.name.should == :YARD
  end

  it "should ensure that the correct object was resolved" do
    foo = ModuleObject.new(:root, :Foo)
    foobar = ModuleObject.new(foo, :Bar)
    foobaz = ClassObject.new(foo, :Baz)

    # Remember, we're looking for Qux::Bar, not just 'Bar'
    proxy = Proxy.new(foobar, 'Foo::Qux::Bar')
    proxy.type.should == :proxy

    qux = ModuleObject.new(foo, :Qux)
    quxbar = ModuleObject.new(qux, :Bar)

    # Now it should resolve
    proxy.type.should == :module
  end

  it "should handle constant names in namespaces" do
    YARD.parse_string <<-eof
      module A; end; B = A
      module B::C; def foo; end end
    eof
    Proxy.new(:root, 'B::C').should == Registry.at('A::C')
  end
  
  describe "link resolution" do
    before do
      Registry.clear
      Registry.links.empty?.should be_true
      
      eval <<-'eof'
        module CodeObjects
          class ClassObject < NamespaceObject
            def linked_by?(title)
              title.to_s == @name.to_s
            end
          end
        end
      eof
    end
    
    after do
      eval <<-'eof'
        module CodeObjects
          class ClassObject < NamespaceObject
            def linked_by?(title)
              super
            end
          end
        end      
      eof
    end
    
    it "should resolve a link to a linkable object using a keyword" do
      Registry.register_link('Class:', :class)
      
      YARD.parse_string 'class Foo; end'
      
      P('Class:').resolve_link('Foo').should == Registry.at('Foo')
      P('Class:').resolve_link('Foo').should be_true
    end
    
    it "should resolve a link to a linkable object using multiple keywords" do
      Registry.register_link('Class:', :class)
      Registry.register_link('Module:', :class)
      
      YARD.parse_string 'class Foo; end'
      
      P('Class:').resolve_link('Foo').should == Registry.at('Foo')
      P('Module:').resolve_link('Foo').should == Registry.at('Foo')
    end
    
    it "should gracefully attempt to resolve a non-linkable object" do
      YARD.parse_string 'class Foo; end'
      
      P('Class:').resolve_link('Foo').should == nil
      P('Module:').resolve_link('Foo').should == nil
    end
    
    it "should gracefully reject an empty object link" do
      Registry.register_link('Class:', :class)
      
      YARD.parse_string 'class Foo; end'
      
      P('Class:').resolve_link(nil).should == nil
    end
    
  end
end
