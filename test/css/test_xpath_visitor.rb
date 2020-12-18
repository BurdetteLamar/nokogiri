# frozen_string_literal: true
require "helper"

class TestNokogiri < Nokogiri::TestCase
  describe Nokogiri::CSS::XPathVisitor do
    let(:parser) { Nokogiri::CSS::Parser.new }

    let(:parser_with_ns) do
      Nokogiri::CSS::Parser.new({
        "xmlns" => "http://default.example.com/",
        "hoge" => "http://hoge.example.com/",
      })
    end

    def assert_xpath(expecteds, asts)
      expecteds = [expecteds].flatten
      expecteds.zip(asts).each do |expected, actual|
        assert_equal(expected, actual.to_xpath)
      end
    end

    it "raises an exception on single quote" do
      assert_raises(Nokogiri::CSS::SyntaxError) { parser.parse("'") }
    end

    it "raises an exception on invalid CSS syntax" do
      assert_raises(Nokogiri::CSS::SyntaxError) { parser.parse("a[x=]") }
    end

    describe "selectors" do
      it "* universal" do
        assert_xpath("//*", parser.parse('*'))
      end

      it "type" do
        assert_xpath('//x', parser.parse('x'))
      end

      it "type with namespaces" do
        assert_xpath("//aaron:a", parser.parse('aaron|a'))
        assert_xpath("//a", parser.parse('|a'))
      end

      it ". class" do
        assert_xpath("//*[contains(concat(' ',normalize-space(@class),' '),' awesome ')]",
                     parser.parse('.awesome'))
        assert_xpath("//foo[contains(concat(' ',normalize-space(@class),' '),' awesome ')]",
                     parser.parse('foo.awesome'))
        assert_xpath("//foo//*[contains(concat(' ',normalize-space(@class),' '),' awesome ')]",
                     parser.parse('foo .awesome'))
        assert_xpath("//foo//*[contains(concat(' ',normalize-space(@class),' '),' awe.some ')]",
                     parser.parse('foo .awe\.some'))
        assert_xpath("//*[contains(concat(' ',normalize-space(@class),' '),' a ') and contains(concat(' ',normalize-space(@class),' '),' b ')]",
                     parser.parse('.a.b'))
      end

      it "# id" do
        assert_xpath("//*[@id='foo']", parser.parse('#foo'))
        assert_xpath("//*[@id='escape:needed,']", parser.parse('#escape\:needed\,'))
        assert_xpath("//*[@id='escape:needed,']", parser.parse('#escape\3Aneeded\,'))
        assert_xpath("//*[@id='escape:needed,']", parser.parse('#escape\3A needed\2C'))
        assert_xpath("//*[@id='escape:needed']", parser.parse('#escape\00003Aneeded'))
      end

      it "ad-hoc combinations" do
        assert_xpath("//*[contains(concat(' ',normalize-space(@class),' '),' pastoral ')]",
                     parser.parse('*.pastoral'))
      end

      describe "attribute" do
        it "basic mechanics" do
          assert_xpath("//h1[@a='Tender Lovemaking']", parser.parse("h1[a='Tender Lovemaking']"))
          assert_xpath("//h1[@a]", parser.parse("h1[a]"))
          assert_xpath(%q{//h1[@a='gnewline\n']}, parser.parse("h1[a='\\gnew\\\nline\\\\n']"))
          assert_xpath("//h1[@a='test']", parser.parse(%q{h1[a=\te\st]}))
        end

        it "parses leading @ (non-standard)" do
          assert_xpath("//a[@id='Boing']", parser.parse("a[@id='Boing']"))
          assert_xpath("//a[@id='Boing']", parser.parse("a[@id = 'Boing']"))
          assert_xpath("//a[@id='Boing']//div", parser.parse("a[@id='Boing'] div"))
        end

        it "namespacing" do
          assert_xpath("//a[@flavorjones:href]", parser.parse('a[flavorjones|href]'))
          assert_xpath("//a[@href]", parser.parse('a[|href]'))
          assert_xpath("//*[@flavorjones:href]", parser.parse('*[flavorjones|href]'))

          ## Default namespace is not applied to attributes, so this is @class, not @xmlns:class.
          assert_xpath("//xmlns:a[@class='bar']", parser_with_ns.parse("a[class='bar']"))
          assert_xpath("//xmlns:a[@hoge:class='bar']", parser_with_ns.parse("a[hoge|class='bar']"))
        end

        it "rhs with quotes" do
          assert_xpath(%q{//h1[@a="'"]}, parser.parse(%q{h1[a="'"]}))
          assert_xpath(%q{//h1[@a=concat("'","")]}, parser.parse("h1[a='\\'']"))
          assert_xpath(%q{//h1[@a=concat("",'"',"'","")]}, parser.parse(%q{h1[a='"\'']}))
        end

        it "rhs is number or string" do
          assert_xpath("//img[@width='200']", parser.parse("img[width='200']"))
          assert_xpath("//img[@width='200']", parser.parse("img[width=200]"))
        end

        it "bare" do
          assert_xpath("//*[@a]//*[@b]", parser.parse("[a] [b]"))
        end

        it "|=" do
          assert_xpath("//a[@class='bar' or starts-with(@class,concat('bar','-'))]",
                       parser.parse("a[@class|='bar']"))
          assert_xpath("//a[@class='bar' or starts-with(@class,concat('bar','-'))]",
                       parser.parse("a[@class |= 'bar']"))
          assert_xpath("//a[@id='Boing' or starts-with(@id,concat('Boing','-'))]",
                       parser.parse("a[id|='Boing']"))
        end

        it "~=" do
          assert_xpath("//a[contains(concat(' ',normalize-space(@class),' '),' bar ')]",
                       parser.parse("a[@class~='bar']"))
          assert_xpath("//a[contains(concat(' ',normalize-space(@class),' '),' bar ')]",
                       parser.parse("a[@class ~= 'bar']"))
          assert_xpath("//a[contains(concat(' ',normalize-space(@class),' '),' bar ')]",
                       parser.parse("a[@class~=bar]"))
          assert_xpath("//a[contains(concat(' ',normalize-space(@class),' '),' bar ')]",
                       parser.parse("a[@class~=\"bar\"]"))
          assert_xpath("//a[contains(concat(' ',normalize-space(@data-words),' '),' bar ')]",
                       parser.parse("a[data-words~=\"bar\"]"))
        end

        it "^=" do
          assert_xpath("//a[starts-with(@id,'Boing')]", parser.parse("a[id^='Boing']"))
          assert_xpath("//a[starts-with(@id,'Boing')]", parser.parse("a[id ^= 'Boing']"))
        end

        it "$=" do
          assert_xpath("//a[substring(@id,string-length(@id)-string-length('Boing')+1,string-length('Boing'))='Boing']",
                       parser.parse("a[id$='Boing']"))
          assert_xpath("//a[substring(@id,string-length(@id)-string-length('Boing')+1,string-length('Boing'))='Boing']",
                       parser.parse("a[id $= 'Boing']"))
        end

        it "*=" do
          assert_xpath("//a[contains(@id,'Boing')]", parser.parse("a[id*='Boing']"))
          assert_xpath("//a[contains(@id,'Boing')]", parser.parse("a[id *= 'Boing']"))
        end

        it "!= (non-standard)" do
          assert_xpath("//a[@id!='Boing']", parser.parse("a[id!='Boing']"))
          assert_xpath("//a[@id!='Boing']", parser.parse("a[id != 'Boing']"))
        end
      end
    end

    describe "pseudo-classes" do
      it ":first-of-type" do
        assert_xpath('//a[position()=1]', parser.parse('a:first-of-type()'))
        assert_xpath('//a[position()=1]', parser.parse('a:first-of-type')) # no parens
        assert_xpath("//a[contains(concat(' ',normalize-space(@class),' '),' b ')][position()=1]",
                     parser.parse('a.b:first-of-type')) # no parens
      end

      it ":nth-of-type" do
        assert_xpath('//a[position()=99]', parser.parse('a:nth-of-type(99)'))
        assert_xpath("//a[contains(concat(' ',normalize-space(@class),' '),' b ')][position()=99]",
                     parser.parse('a.b:nth-of-type(99)'))
      end

      it ":last-of-type" do
        assert_xpath('//a[position()=last()]', parser.parse('a:last-of-type()'))
        assert_xpath('//a[position()=last()]', parser.parse('a:last-of-type')) # no parens
        assert_xpath("//a[contains(concat(' ',normalize-space(@class),' '),' b ')][position()=last()]",
                     parser.parse('a.b:last-of-type')) # no parens
      end

      it ":nth-last-of-type" do
        assert_xpath('//a[position()=last()]', parser.parse('a:nth-last-of-type(1)'))
        assert_xpath('//a[position()=last()-98]', parser.parse('a:nth-last-of-type(99)'))
        assert_xpath("//a[contains(concat(' ',normalize-space(@class),' '),' b ')][position()=last()-98]",
                     parser.parse('a.b:nth-last-of-type(99)'))
      end

      it ":nth and friends (non-standard)" do
        assert_xpath('//a[position()=1]', parser.parse('a:first()'))
        assert_xpath('//a[position()=1]', parser.parse('a:first')) # no parens
        assert_xpath('//a[position()=99]', parser.parse('a:eq(99)'))
        assert_xpath('//a[position()=99]', parser.parse('a:nth(99)'))
        assert_xpath('//a[position()=last()]', parser.parse('a:last()'))
        assert_xpath('//a[position()=last()]', parser.parse('a:last')) # no parens
        assert_xpath('//a[node()]', parser.parse('a:parent'))
      end

      it ":nth-child and friends" do
        assert_xpath('//a[count(preceding-sibling::*)=0]', parser.parse('a:first-child'))
        assert_xpath('//a[count(preceding-sibling::*)=98]', parser.parse('a:nth-child(99)'))
        assert_xpath('//a[count(following-sibling::*)=0]', parser.parse('a:last-child'))
        assert_xpath('//a[count(following-sibling::*)=0]', parser.parse('a:nth-last-child(1)'))
        assert_xpath('//a[count(following-sibling::*)=98]', parser.parse('a:nth-last-child(99)'))
      end

      it "[n] as :nth-child (non-standard)" do
        assert_xpath("//a[count(preceding-sibling::*)=1]", parser.parse("a[2]"))
      end

      it ":has()" do
        assert_xpath("//a[.//b]", parser.parse("a:has(b)"))
        assert_xpath("//a[.//b/c]", parser.parse("a:has(b > c)"))
        assert_xpath("//a[./b]", parser.parse("a:has(> b)"))
        assert_xpath("//a[./following-sibling::b]", parser.parse("a:has(~ b)"))
        assert_xpath("//a[./following-sibling::*[1]/self::b]", parser.parse("a:has(+ b)"))
      end

      it ":only-child" do
        assert_xpath('//a[count(preceding-sibling::*)=0 and count(following-sibling::*)=0]',
                     parser.parse('a:only-child'))
      end

      it ":only-of-type" do
        assert_xpath('//a[last()=1]', parser.parse('a:only-of-type'))
      end

      it ":empty" do
        assert_xpath('//a[not(node())]', parser.parse('a:empty'))
      end

      it ":nth(an+b)" do
        assert_xpath('//a[(position() mod 2)=0]', parser.parse('a:nth-of-type(2n)'))
        assert_xpath('//a[(position()>=1) and (((position()-1) mod 2)=0)]', parser.parse('a:nth-of-type(2n+1)'))
        assert_xpath('//a[(position() mod 2)=0]', parser.parse('a:nth-of-type(even)'))
        assert_xpath('//a[(position()>=1) and (((position()-1) mod 2)=0)]', parser.parse('a:nth-of-type(odd)'))
        assert_xpath('//a[(position()>=3) and (((position()-3) mod 4)=0)]', parser.parse('a:nth-of-type(4n+3)'))
        assert_xpath('//a[position()<=3]', parser.parse('a:nth-of-type(-1n+3)'))
        assert_xpath('//a[position()<=3]', parser.parse('a:nth-of-type(-n+3)'))
        assert_xpath('//a[position()>=3]', parser.parse('a:nth-of-type(1n+3)'))
        assert_xpath('//a[position()>=3]', parser.parse('a:nth-of-type(n+3)'))

        assert_xpath('//a[((last()-position()+1) mod 2)=0]', parser.parse('a:nth-last-of-type(2n)'))
        assert_xpath('//a[((last()-position()+1)>=1) and ((((last()-position()+1)-1) mod 2)=0)]', parser.parse('a:nth-last-of-type(2n+1)'))
        assert_xpath('//a[((last()-position()+1) mod 2)=0]', parser.parse('a:nth-last-of-type(even)'))
        assert_xpath('//a[((last()-position()+1)>=1) and ((((last()-position()+1)-1) mod 2)=0)]', parser.parse('a:nth-last-of-type(odd)'))
        assert_xpath('//a[((last()-position()+1)>=3) and ((((last()-position()+1)-3) mod 4)=0)]', parser.parse('a:nth-last-of-type(4n+3)'))
        assert_xpath('//a[(last()-position()+1)<=3]', parser.parse('a:nth-last-of-type(-1n+3)'))
        assert_xpath('//a[(last()-position()+1)<=3]', parser.parse('a:nth-last-of-type(-n+3)'))
        assert_xpath('//a[(last()-position()+1)>=3]', parser.parse('a:nth-last-of-type(1n+3)'))
        assert_xpath('//a[(last()-position()+1)>=3]', parser.parse('a:nth-last-of-type(n+3)'))
      end

      it ":not()" do
        assert_xpath('//ol/*[not(self::li)]', parser.parse('ol > *:not(li)'))
        assert_xpath("//*[@id='p' and not(contains(concat(' ',normalize-space(@class),' '),' a '))]",
                     parser.parse('#p:not(.a)'))
        assert_xpath("//p[contains(concat(' ',normalize-space(@class),' '),' a ') and not(contains(concat(' ',normalize-space(@class),' '),' b '))]",
                     parser.parse('p.a:not(.b)'))
        assert_xpath("//p[@a='foo' and not(contains(concat(' ',normalize-space(@class),' '),' b '))]",
                     parser.parse("p[a='foo']:not(.b)"))
      end

      it "chained :not()" do
        assert_xpath("//p[not(contains(concat(' ',normalize-space(@class),' '),' a ')) and not(contains(concat(' ',normalize-space(@class),' '),' b ')) and not(contains(concat(' ',normalize-space(@class),' '),' c '))]",
                     parser.parse("p:not(.a):not(.b):not(.c)"))
      end

      it "combinations of :not() and nth-and-friends" do
        assert_xpath('//ol/*[not(count(following-sibling::*)=0)]',
                     parser.parse('ol > *:not(:last-child)'))
        assert_xpath('//ol/*[not(count(preceding-sibling::*)=0 and count(following-sibling::*)=0)]',
                     parser.parse('ol > *:not(:only-child)'))
      end

      it "miscellaneous pseudo-classes are converted into xpath function calls" do
        assert_xpath("//a[aaron(.)]", parser.parse('a:aaron'))
        assert_xpath("//a[aaron(.)]", parser.parse('a:aaron()'))
        assert_xpath("//a[aaron(.,12)]", parser.parse('a:aaron(12)'))
        assert_xpath("//a[aaron(.,12,1)]", parser.parse('a:aaron(12, 1)'))

        assert_xpath("//a[link(.)]", parser.parse('a:link'))
        assert_xpath("//a[visited(.)]", parser.parse('a:visited'))
        assert_xpath("//a[hover(.)]", parser.parse('a:hover'))
        assert_xpath("//a[active(.)]", parser.parse('a:active'))

        assert_xpath("//a[foo(.,@href)]", parser.parse('a:foo(@href)'))
        assert_xpath("//a[foo(.,@a,b)]", parser.parse('a:foo(@a, b)'))
        assert_xpath("//a[foo(.,a,10)]", parser.parse('a:foo(a, 10)'))
        assert_xpath("//a[foo(.,42)]", parser.parse('a:foo(42)'))
        assert_xpath("//a[foo(.,'bar')]", parser.parse('a:foo(\'bar\')'))
      end

      it "bare pseudo-class matches any ident" do
        assert_xpath("//*[link(.)]", parser.parse(':link'))
        assert_xpath("//*[not(@id='foo')]", parser.parse(':not(#foo)'))
        assert_xpath("//*[count(preceding-sibling::*)=0]", parser.parse(":first-child"))
      end
    end

    describe "combinators" do
      it "descendant" do
        assert_xpath('//x//y', parser.parse('x y'))
      end

      it "~ general sibling" do
        assert_xpath("//E/following-sibling::F", parser.parse("E ~ F"))
        assert_xpath("//E/following-sibling::F//G", parser.parse("E ~ F G"))
      end

      it "~ general sibling prefixless is relative to context node" do
        assert_xpath("./following-sibling::a", parser.parse('~a'))
        assert_xpath("./following-sibling::a", parser.parse('~ a'))
        assert_xpath("./following-sibling::a//b/following-sibling::i", parser.parse('~a b~i'))
        assert_xpath("./following-sibling::a//b/following-sibling::i", parser.parse('~ a b ~ i'))
      end

      it "+ adjacent sibling" do
        assert_xpath("//E/following-sibling::*[1]/self::F", parser.parse("E + F"))
        assert_xpath("//E/following-sibling::*[1]/self::F//G", parser.parse("E + F G"))
      end

      it "+ adjacent sibling prefixless is relative to context node" do
        assert_xpath("./following-sibling::*[1]/self::a", parser.parse('+a'))
        assert_xpath("./following-sibling::*[1]/self::a", parser.parse('+ a'))
        assert_xpath("./following-sibling::*[1]/self::a/following-sibling::*[1]/self::b", parser.parse('+a+b'))
        assert_xpath("./following-sibling::*[1]/self::a/following-sibling::*[1]/self::b", parser.parse('+ a + b'))
      end

      it "> child" do
        assert_xpath('//x/y', parser.parse('x > y'))
        assert_xpath("//a//b/i", parser.parse('a b>i'))
        assert_xpath("//a//b/i", parser.parse('a b > i'))
        assert_xpath("//a/b/i", parser.parse('a > b > i'))
      end

      it "> child prefixless is relative to context node" do
        assert_xpath("./a", parser.parse('>a'))
        assert_xpath("./a", parser.parse('> a'))
        assert_xpath("./a//b/i", parser.parse('>a b>i'))
        assert_xpath("./a/b/i", parser.parse('> a > b > i'))
      end

      it "/ (non-standard)" do
        assert_xpath('//x/y', parser.parse('x/y'))
        assert_xpath('//x/y', parser.parse('x / y'))
      end

      it "// (non-standard)" do
        assert_xpath('//x//y', parser.parse('x//y'))
        assert_xpath('//x//y', parser.parse('x // y'))
      end
    end

    describe "functions" do
      it "handles text() (non-standard)" do
        assert_xpath("//a[child::text()]", parser.parse("a[text()]"))
        assert_xpath("//child::text()", parser.parse("text()"))
      end

      it "handles comment() (non-standard)" do
        assert_xpath("//script//comment()", parser.parse("script comment()"))
      end

      it "supports custom functions" do
        visitor = Class.new(Nokogiri::CSS::XPathVisitor) do
          attr_accessor :awesome
          def visit_function_aaron(node)
            @awesome = true
            'aaron() = 1'
          end
        end.new
        ast = parser.parse('a:aaron()').first
        assert_equal 'a[aaron() = 1]', visitor.accept(ast)
        assert visitor.awesome
      end

      it "supports custom pseudo-classes" do
        visitor = Class.new(Nokogiri::CSS::XPathVisitor) do
          attr_accessor :awesome
          def visit_pseudo_class_aaron(node)
            @awesome = true
            'aaron() = 1'
          end
        end.new
        ast = parser.parse('a:aaron').first
        assert_equal 'a[aaron() = 1]', visitor.accept(ast)
        assert visitor.awesome
      end
    end

    it "handles pseudo-class with class selector" do
      assert_xpath("//a[active(.) and contains(concat(' ',normalize-space(@class),' '),' foo ')]",
                   parser.parse('a:active.foo'))
      assert_xpath("//a[contains(concat(' ',normalize-space(@class),' '),' foo ') and active(.)]",
                   parser.parse('a.foo:active'))
    end

    it "handles pseudo-class with an id selector" do
      assert_xpath("//a[@id='foo' and active(.)]", parser.parse('a#foo:active'))
      assert_xpath("//a[active(.) and @id='foo']", parser.parse('a:active#foo'))
    end

    it "handles function with pseudo-class" do
      assert_xpath('//child::text()[position()=99]', parser.parse('text():nth-of-type(99)'))
    end

    it "handles multiple selectors" do
      assert_xpath(['//x/y', '//y/z'], parser.parse('x > y, y > z'))
      assert_xpath(['//x/y', '//y/z'], parser.parse('x > y,y > z'))
      ###
      # TODO: should we make this work?
      # assert_xpath ['//x/y', '//y/z'], parser.parse('x > y | y > z')
    end
  end
end
