[![Test](https://github.com/wvk/caracal/actions/workflows/ci.yml/badge.svg)](https://github.com/wvk/caracal/actions/workflows/ci.yml)

# Caracal

This fork includes fixes and functionalities from pending PRs from the original project, to be able to use them while waiting for the PRs to be merged there.
Original [![Gem Version](http://img.shields.io/gem/v/caracal.svg?style=flat)](https://rubygems.org/gems/caracal)

## Overview

Caracal is a ruby library for dynamically creating professional-quality Microsoft Word documents using an HTML-style syntax.

Caracal is not a magical HTML to Word translator. Instead, it is a markup language for generating Office Open XML (OOXML). Programmers create Word documents by issuing a series of simple commands against a document object. When the document is rendered, Caracal takes care of translating those Ruby commands into the requisite OOXML. At its core, the library is essentially a templating engine for the `:docx` format.

Or, said differently, if you use [Prawn](https://github.com/prawnpdf/prawn) for PDF generation, you'll probably like Caracal. Only you'll probably like it better. :)

Please see the [caracal-example](https://github.com/urvin-compliance/caracal-example) repository for
a working demonstration of the library's capabilities.


## Teaser

How would you like to make a Word document like this?

```ruby
Caracal::Document.save 'example.docx' do |docx|
  # page 1
  docx.h1 'Page 1 Header'
  docx.hr
  docx.p
  docx.h2 'Section 1'
  docx.p  'Lorem ipsum dolor....'
  docx.p
  docx.table @my_data, border_size: 4 do
    cell_style rows[0], bgcolor: 'cccccc', bold: true
  end

  # page 2
  docx.page
  docx.h1 'Page 2 Header'
  docx.hr
  docx.p
  docx.h2 'Section 2'
  docx.p  'Lorem ipsum dolor....'
  docx.ul do
    li 'Item 1'
    li 'Item 2'
  end
  docx.p
  docx.img 'https://www.example.com/logo.png', width: 500, height: 300
end
```

**You can!** Read on.


## Why is Caracal Needed?

We created Caracal to satisfy a genuine business requirement.  We were working on a system that produced a periodic PDF report and our clients asked if the report could instead be generated as a Word document, which would allow them to perform edits before passing the report along to their clients.

Now, as you may have noticed, the Ruby community has never exactly been known for its enthusiastic support of Microsoft standards. So it might not surprise you to learn that the existing options on Rubygems for Word document generation were limited.  Those libraries, by and large, fell into a couple of categories:

* **HTML to Word Convertors**
We understand the motivating idea here (two output streams from one set of instructions), but the reality is the number of possible permutations of nested HTML tags is simply too great for this strategy to ever work for anything other than the simplest kinds of documents. Most of these libraries rely on a number of undocumented assumptions about the structure of your HTML (which undermines the whole value proposition of a convertor) and fail to support basic features of a professional-quality Word document (e.g., images, lists, tables, etc). The remaining libraries simply did not work at all.

* **Weekend Projects**
We also found a number of inactive projects that appeared to be experiments in the space. Obviously, these libraries were out of the question for a commercial product.

What we wanted was a Prawn-style library for the `:docx` format. In the absence of an active project organized along those lines, we decided to write one.


## Design

Caracal is designed to separate the process of parsing and collecting rendering instructions from the process of rendering itself.

First, the library consumes all programmer instructions and organizes several collections of data models that capture those instructions. These collections are ordered and nested exactly as the instructions were given. Each model contains all the data required to render it and is responsible for declaring itself valid or invalid.

*Note: Some instructions create more than one model. For example, the `iframe` method appends an `IFrameModel` to the main contents collection and adds the embedded document's namespaces to the namespaces collection. Rendering adds models too: each rendered image adds a `RelationshipModel` to the relationships of its part.*

Only after all the programmer instructions have been parsed does the document attempt to render the data to XML. This strategy gives the rendering process a tremendous amount of flexibility in the rare cases where renderers combine data from more than one collection.


## File Structure

You may not know that .docx files are simply a zipped collection of XML documents that follow the OOXML standard. (We didn't, in any event.) This means constructing a .docx file from scratch actually requires the creation of several files.  Caracal abstracts users from this process entirely.

For each Caracal request, the following document structure will be created and zipped into the final output file (parts marked * only when used):

```
    example.docx
      |- _rels
        |- .rels
      |- docProps
        |- app.xml
        |- core.xml
        |- custom.xml
      |- word
        |- _rels
          |- document.xml.rels
          |- fontTable.xml.rels    *
          |- header1.xml.rels      *
          |- header2.xml.rels      *
          |- footer1.xml.rels      *
          |- footer2.xml.rels      *
        |- fonts                   *
          |- font1.odttf
          ...
        |- media                   *
          |- image-3f2a9c41d07e5b68.png
          ...
        |- theme
          |- theme1.xml
        |- document.xml
        |- fontTable.xml
        |- footer1.xml             *
        |- footer2.xml             *
        |- header1.xml             *
        |- header2.xml             *
        |- numbering.xml
        |- settings.xml
        |- styles.xml
      |- [Content_Types].xml
```


## File Descriptions

The following provides a brief description for each component of the final document:

**_rels/.rels**
Defines an internal identifier and type for global content items. *This file is generated automatically by the library based on other user directives.*

**docProps/app.xml**
Specifies the name of the application that generated the document. *This file is generated automatically by the library based on other user directives.*

**docProps/core.xml**
Specifies the title, subject, creator and other [document properties](#document-properties). *This file is generated automatically by the library based on other user directives.*

**docProps/custom.xml**
Specifies the custom document properties. *This file is generated automatically by the library based on other user directives.*

**word/_rels/document.xml.rels**
Defines an internal identifier and type with all external content items (images, links, etc). *This file is generated automatically by the library based on other user directives.*

**word/media/**
The images, named `image-<16 hex digits>.<ext>` after their URL and data. Each has an entry in the `.rels` file of the part showing it.

**word/document.xml**
The main content file for the document.

**word/fontTable.xml**
Specifies the fonts used in the document.

**word/fonts/** and **word/_rels/fontTable.xml.rels**
Embedded font files and their links from the font table. Only present when fonts are embedded.

**word/header1.xml** and **word/footer1.xml**
The page header and footer, present when the document has one. `header2.xml` and `footer2.xml` hold the first page's header and footer when the first page differs and shows content there. Each part's images and links are listed in its own `.rels` file, e.g. `word/_rels/header1.xml.rels`.

**word/numbering.xml**
Defines the list styles and the heading numbering.

**word/theme/theme1.xml**
The color and font theme. See [Color Themes](#color-themes).

**word/settings.xml**
Defines global directives for the document (e.g., whether to show background images, tab widths, etc). Also, establishes compatibility with older versions of Word.

**word/styles.xml**
Defines the paragraph, character and table styles used throughout the document. Caracal adds a default set of styles to match its HTML-like content syntax; you can override them.

**[Content_Types].xml**
Pairs extensions and XML files with schema content types so Word can parse them correctly. *This file is generated automatically by the library based on other user directives.*


## Units

OpenXML properties are specified in several different units, depending on which attribute is being set.

**Points**
Border and rule spacing is measured in full points.

**Half Points**
All font sizes are measured in half points.  A font size of 24 is equivalent to 12pt.

**Eighth Points**
Border and rule sizes are measured in 1/8 points.  A border size of 4 is equivalent to 0.5pt.

**Twips**
A twip is 1/20 of a point.  Paragraph spacing, indentation, page sizes and page margins are measured in twips.  1in == 72pt == 1440 twips.

**Pixels**
Image width and height are measured in pixels, converted at `ppi` (72 by default, where 1px == 1pt). See [Images](#images).

**EMUs (English Metric Unit)**
EMUs are a virtual unit designed to facilitate the smooth conversion between inches, millimeters, and pixels for images and vector graphics.  1in == 914400 EMUs.  1px at 72dpi == 1pt == 12700 EMUs.

Caracal takes each value in the unit OOXML uses for it, except for images: width and height in pixels, margins in points and anchor offsets in twips, all converted to EMUs.


## Syntax Flexibility

Generally speaking, Caracal commands will accept instructions via any combination of a parameters hash and/or a block.  For example, all of the following commands are equivalent.

```ruby
docx.style id: 'special', name: 'Special', size: 24, bold: true

docx.style id: 'special', size: 24 do
  name 'Special'
  bold true
end

docx.style do
  id   'special'
  name 'Special'
  size 24
  bold true
end
```

Parameter options are always evaluated before block options. This means if the same option is provided in the parameter hash and in the block, the value in the block will overwrite the value from the parameter hash. Tread carefully.


## Validations

Each command validates its options and raises `Caracal::Errors::InvalidModelError` for invalid values. An unknown option raises a `RuntimeError` naming it.


## Security

Caracal reads whatever path or URL you hand it. Both `img` and `iframe` accept a local filesystem path or an http(s) URL, and Caracal reads or fetches it while building or rendering the document. `font` reads local font files.

**Treat those values as trusted input.** If a path or URL can be influenced by an end user, validate it before passing it to Caracal:

* **Local paths** are read with the permissions of your application's process. Any file that process can read can be embedded in the generated document, so `docx.img '/etc/passwd', width: 10, height: 10` embeds the contents of that file.
* **URLs** are fetched from your application's network position, and redirects are followed. A user-supplied URL can therefore reach internal services, `localhost`, or cloud metadata endpoints that are not otherwise reachable from outside.
* **Font files** given to `font` (`regular`, `bold`, `italic`, `bold_italic`) are read from local paths.
* **Documents embedded with `iframe`** are parsed, and their markup is copied into your output. Only embed documents you trust. See [IFrames](#iframes).

Caracal reads http(s) URLs with `URI.open` and everything else with `File.binread`, so a path is always read as a file. It leaves restricting paths, hosts and directories to your application, which knows what is legitimate: an allowlist of permitted directories or hosts, or never passing user-supplied values through to Caracal.


## Installation

Caracal requires Ruby 3.2 or later.

Version 2 is installed from GitHub; the `caracal` gem on rubygems.org is the original project's 1.x line. Add this line to your application's Gemfile:

```ruby
gem 'caracal', github: 'wvk/caracal'
```

Then execute:

```bash
bundle install
```


## Commands

In the following examples, the variable `docx` is assumed to be an instance of Caracal::Document.

```ruby
docx = Caracal::Document.new('example_document.docx')
```

Most code examples show optional values being passed in a block.  As noted above, you may also pass these options as a parameter hash or as a combination of a parameter hash and a block.


### File Name

The output file name can be set at initialization or via the `file_name` method. A name with directories saves the file there.

```ruby
docx = Caracal::Document.new('example_document.docx')

docx.file_name 'different_name.docx'
```

The current document name can be returned by invoking the `name` method:

```ruby
docx.name    # => 'different_name.docx'
```

*The default file name is caracal.docx.*


### Page Size

Page dimensions can be set using the `page_size` method.  The method accepts two parameters for controlling the width and height of the document. Parameters not given keep their current value.
It also accepts a third parameter for setting the page orientation.  If you want landscape orientation, you need to change both the page
dimensions and the orientation explicitly.

*Page size defaults to US Letter, portrait dimensions (8.5in x 11in).*

```ruby
docx.page_size do
  width       15840       # sets the page width. units in twips.
  height      12240       # sets the page height. units in twips.
  orientation :landscape  # sets the printer orientation. accepts :portrait and :landscape.
end
```

Both the `width` and `height` attributes require positive integer values.


### Page Margins

Page margins can be set using the `page_margins` method.  The method accepts four parameters for controlling the margins of the document. Sides not given keep their current value.

*Margins default to 1.0in for all sides.*

```ruby
docx.page_margins do
  left    720     # sets the left margin. units in twips.
  right   720     # sets the right margin. units in twips.
  top     1440    # sets the top margin. units in twips.
  bottom  1440    # sets the bottom margin. units in twips.
end
```

All attributes require positive integer values. The margins on either axis must sum to less than the page size on that axis (e.g., `left` + `right` < page width); `page_margins` and `page_size` raise `Caracal::Errors::InvalidModelError` otherwise.


### Page Columns

Text can be set in up to 45 columns using the `page_columns` method. `column_break` continues the text at the top of the next column, at the document level or inside a paragraph.

```ruby
docx.page_columns 2, spacing: 360   # two columns, 360 twips apart. spacing defaults to 720.

docx.p 'First column.'
docx.column_break
docx.p 'Second column.'
```

Rules fit one column. Tables added after `page_columns` default to the width of one column.


### Page Breaks

Page breaks can be added via the `page` method.  The method accepts no parameters.

```ruby
docx.page     # starts a new page.
```


### Page Numbers

The `page_numbers` method adds a paragraph with the page number to the end of the footer, creating the footer if needed.

*Page numbers are turned off by default.*

```ruby
docx.page_numbers true do
  align       :right  # sets the alignment. accepts :left, :center, and :right. defaults to :center.
  label       'Page'  # sets the text that will go to the left of the page number. defaults to nil.
  label_size  24      # sets the label size only. units in half points.
  number_size 20      # sets the number size only. units in half points.
end

docx.page_numbers true, label: 'Page', size: 24  # size sets the label and number size simultaneously.
```

The `size` option and the `label_size` and `number_size` options are mutually exclusive.

The `start` option sets the number of the first page, which is useful when the document continues another one, or has a cover page you don't want counted. It also applies to `field :page` in a custom footer, so it can be set without showing the built-in page number:

```ruby
docx.page_numbers true, start: 0   # the cover page is page 0, so the next page is page 1
docx.page_numbers start: 12        # number from 12 without the built-in page number
```

The page number appears on the first page too unless you pass `first_page: false`; see [Different First Page](#different-first-page).


### Headers and Footers

Headers and footers are repeated on every page. They take the same content as the document body, in the order given, except page breaks and a table of contents.

```ruby
docx.header.h1 'Page Header'

docx.header do
  p 'Headers can contain headings, paragraphs, images, lists and tables.'
  p 'This paragraph is right-aligned.', align: :right
end

docx.header.img 'http://example.com/image.png' do
  width  60
  height 60
  align :right
end

docx.header.ol do
  li 'First item'
  li do
    text 'Second item with a '
    link 'link', "http://example.com/image.png"
    text '.'
    br
    text 'This sentence follows a line break.'
  end
end

docx.header.table [['11', '1213', '14'], ['21', '22', '23', '24']] do
  cell_style rows[0][0], rowspan: 2
  cell_style rows[0][1], colspan: 2
  cell_style rows[0][2], rowspan: 2
end

docx.header.hr

docx.footer.p 'Footers work the same way.', align: :center
```

#### Different First Page

Pass `first: true` to give the first page its own header or footer, such as a cover page. Without a block, the first page's header or footer stays empty, apart from the page number. Use `first_page: false` to leave the page number off the first page.

```ruby
docx.header first: true do       # replaces the header on the first page only
  p 'Annual Report 2026', align: :center, size: 36
end
```

```ruby
docx.header first: true          # no header on the first page
docx.footer first: true          # no footer content on the first page
docx.page_numbers true, first_page: false   # no page number on the first page
```

When the first page has its own header or footer, any part you don't set for it shows the default one. So `first_page: false` on its own hides only the page number, and the default header and footer content still appear.

### Fonts

Fonts are added to the font table file by calling the `font` method and passing the name of the font.

```ruby
docx.font do
  name 'Droid Serif'
end
```

#### Embedding fonts

Fonts can be embedded into the document, so it renders correctly on systems that don't have the font installed. Pass the font file for each style you use, as a file path or an IO:

```ruby
docx.font do
  name        'Source Serif Pro'                     # must match the font's family name
  regular     'fonts/SourceSerifPro-Regular.ttf'
  bold        'fonts/SourceSerifPro-Bold.ttf'
  italic      'fonts/SourceSerifPro-It.ttf'
  bold_italic File.open('fonts/SourceSerifPro-BoldIt.ttf', 'rb')
end

docx.font name: 'Source Serif Pro', regular: 'fonts/SourceSerifPro-Regular.ttf'   # or as options
```

All styles of one font should be files of the same font family: Word uses only one embedded font per font name.

Embedded fonts are obfuscated as required by ECMA-376 §17.8.1. Use `obfuscate false` to embed the plain font files instead; Word reads those as well.

The fonts embedded in a Word template are obfuscated `.odttf` files in its `word/fonts/` folder. Pass such a file with its `key`: the `w:fontKey` GUID of the `w:embedRegular`, `w:embedBold`, … element in the template's `word/fontTable.xml` whose `r:id` names the file in `word/_rels/fontTable.xml.rels`. Word gives every file its own key, so `key` takes one GUID for all styles of the font or a Hash of GUIDs by style; styles without a key are read as plain font files. The braces around the GUID are optional. Caracal de-obfuscates each file and embeds it like any other font file.

```ruby
docx.font name: 'Work Sans', regular: 'template/word/fonts/font4.odttf', key: '{6F1C2A9E-4B7D-4E21-A3C5-8D90B1E2F347}'

docx.font do
  name    'Assistant'
  regular 'template/word/fonts/font1.odttf'
  bold    'template/word/fonts/font2.odttf'
  key     regular: '{3D8A5B10-7C2E-4F69-9E41-B6A0C5D7E812}', bold: '{A47E0C93-1B5F-4D28-8C6A-2F9E3B4D5061}'
end
```

Caracal checks every font file when it is added and raises `Caracal::Errors::InvalidFontError` if

* an `.odttf` file does not de-obfuscate to a font with its `key`, as with a wrong key, or the key is not a GUID,
* the file is not a single TrueType/OpenType font (font collections and WOFF files are not supported),
* the font has CFF (PostScript) outlines, which is common for `.otf` files: only TrueType outlines are supported,
* the font's license forbids embedding (OpenType `fsType`: Restricted License, or Bitmap embedding only).

Fonts licensed for Preview & Print embedding only are embedded with a warning: Word opens documents containing them read-only.


### Styles

Paragraph style classes are defined with the `style` method. `id` and `name` are required; the other options control the rendering of text using the style.

```ruby
docx.style do
  id              'Heading1'  # sets the internal identifier for the style.
  name            'heading 1' # sets the friendly name of the style.
  type            'paragraph' # sets the style type. accepts `paragraph`, `character` or `table` (see Table Styles).
  font            'Palatino'  # sets the font family.
  color           '333333'    # sets the text color. accepts hex RGB.
  size            28          # sets the font size. units in half points.
  bold            false       # sets the font weight.
  italic          false       # sets the font style.
  underline       false       # sets whether or not to underline the text.
  caps            false       # sets whether or not text should be rendered in all capital letters.
  align           :left       # sets the alignment. accepts :left, :center, :right, and :both.
  line            360         # sets the minimum line height. units in twips.
  line_rule       :at_least   # accepts :at_least, :exact and :auto (line in 240ths of a line).
  top             100         # sets the spacing above the paragraph. units in twips.
  bottom          0           # sets the spacing below the paragraph. units in twips.
  indent_left     360         # sets the left indent. units in twips.
  indent_right    360         # sets the right indent. units in twips.
  indent_first    720         # sets the first line indent. units in twips.
  bidi            true        # sets right-to-left paragraph direction.
end
```

In paragraph styles, `left` and `right` are short for `indent_left` and `indent_right`.

Caracal defines these styles for every document: paragraph styles Normal, Title, Subtitle, Heading, Heading1–Heading6, Header, Footer, Caption, TOCHeading and TOC1–TOC6, and the character style Hyperlink. A `style` command with an existing id replaces that style.

Styles are declared as `paragraph` by default. If you need to adjust inline text styles repeatedly, you might
benefit from defining a `character` style.  Paragraph styles affect all text runs within a paragraph; character styles
are used to style individual runs within a larger text block.
Character styles use the text options only (font, color, size, bold, …) and are applied to text runs and links with the
`style` option, e.g. `text 'x', style: 'MyCharStyle'`.

One-off inline text styling can also be accomplished by passing the `text` command override arguments (see below).


### Document Properties

The title, subject, author and other core properties of the document are set with these methods and written to `docProps/core.xml`.

```ruby
docx.title            'Quarterly report'
docx.subject          'Sales figures'
docx.creator          'ACME Reporting'      # the author
docx.keywords         'sales, quarterly'    # or an array: %w(sales quarterly)
docx.description      'Figures for the third quarter.'
docx.last_modified_by 'Jane Doe'
docx.created          Date.new(2024, 5, 17)
docx.modified         Time.now
```

Called without a value, each method returns the property's value. `created` and `modified` accept a Date, Time, DateTime or parseable String such as `'2024-05-17T14:30:00+02:00'` and are written in UTC; other values raise `Caracal::Errors::InvalidModelError`. Keywords given as an array are joined with commas. Properties not set are not written, except the title, which defaults to the file name.


### Custom Properties

Custom document properties can be defined using the `custom_property` method.  The method accepts a few required parameters to control the definition of the custom property.

```ruby
docx.custom_property do
  name      'property name 1' # sets the name of the custom property.
  value     'test'            # sets the value of the custom property.
  type      :text             # sets the property type. accepts :text, :number, :date, :boolean.
end

docx.custom_property name: 'Due', value: Date.new(2024, 5, 17), type: :date
docx.custom_property name: 'Amount', value: 12.5, type: :number
```

The `name`, `value`, and `type` attributes are required. A `:date` value may be a Date, Time, DateTime or parseable String. A `:number` value is stored as an integer when it is a whole number within 32 bits, otherwise as a floating point number. A `:boolean` value is `true` or `false`; other values are stored as text. Invalid properties raise `Caracal::Errors::InvalidModelError`.

A document may have zero or many custom properties. Each custom property's `name` should be unique with its `type`.



### Paragraphs

Paragraph text can be added using the `p` method.  The method accepts several optional parameters for controlling the style and behavior of the paragraph.

In its simple form, a paragraph accepts a text string and formatting options.

```ruby
docx.p 'Sample text.'

docx.p 'Sample text.', style: 'custom_style'

docx.p 'Sample text.' do
  style           'custom_style'    # sets the paragraph style. generally used at the exclusion of other attributes.
  align           :left             # sets the alignment. accepts :left, :center, :right, and :both.
  color           '333333'          # sets the font color.
  size            32                # sets the font size. units in 1/2 points.
  bold            true              # sets whether or not to render the text with a bold weight.
  italic          false             # sets whether or not to render the text in italic style.
  underline       false             # sets whether or not to underline the text.
  bgcolor         'cccccc'          # sets the background color.
  highlight_color 'yellow'          # sets the highlight color. accepts the names listed below.
  vertical_align  'superscript'     # sets the vertical alignment.
  keep_next       false             # sets whether or not to keep this paragraph with the next paragraph when separated by page break.
  keep_lines      true              # keeps all lines of the paragraph on the same page.
  widow_control   true              # keeps a paragraph's first or last line from standing alone on a page.
  line            360               # sets the minimum line height. units in twips.
  line_rule       :at_least         # accepts :at_least, :exact and :auto (line in 240ths of a line).
  top             100               # sets the spacing above the paragraph. units in twips.
  bottom          100               # sets the spacing below the paragraph. units in twips.
  left            720               # sets the left indent of every line. units in twips.
  right           720               # sets the right indent of every line. units in twips.
  bidi            true              # sets right-to-left paragraph direction, for Arabic or Hebrew text.
end
```

`highlight_color` accepts `black`, `blue`, `cyan`, `green`, `magenta`, `red`, `yellow`, `white`, `darkBlue`, `darkCyan`, `darkGreen`, `darkMagenta`, `darkRed`, `darkYellow`, `darkGray`, `lightGray` and `none` for paragraphs, text runs, links and styles. Other values raise `Caracal::Errors::InvalidModelError`.

Paragraphs and paragraph styles accept the table border options (see Tables), e.g. `docx.p 'Boxed', border_color: '666666'` or `border_bottom: { size: 12 }`. `border_horizontal` sets the line between consecutive paragraphs with the same borders.

More complex paragraph runs can be accomplished by using the `text` method inside the paragraph's block.

```ruby
docx.p do
  text 'Here is a sentence with a '
  link 'link', 'https://www.example.com'
  text ' to something awesome', font: 'Courier New', color: '555555', size: 32, bold: true, italic: true, underline: true, bgcolor: 'cccccc'
  text '.'
  br
  text 'This text follows a line break and uses a character style instead of overrides.', style: 'MyCharStyle'
  page
end
```


### Links

Links can be added inside paragraphs using the `link` method.  The method accepts several optional parameters for controlling the style and behavior of the link.

```ruby
docx.p do
  link 'Example Text', 'https://www.example.com' do
    internal        false             # links to the bookmark named by the second argument instead of a url. defaults to false.
    style           'Hyperlink'       # sets the character style. defaults to nil.
    font            'Courier New'     # sets the font name to use. defaults to the paragraph's.
    color           '0000ff'          # sets the color of the text. defaults to the paragraph's, else the style's, else 1155cc.
    size            24                # sets the font size. units in half-points. defaults to the paragraph's.
    bold            false             # sets whether or not the text will be bold. defaults to the paragraph's.
    italic          false             # sets whether or not the text will be italic. defaults to the paragraph's.
    underline       true              # sets whether or not the text will be underlined. defaults to the paragraph's, else the style's, else true.
    bgcolor         'cccccc'          # sets the background color.
    highlight_color 'yellow'          # sets the highlight color. accepts the names listed under Paragraphs.
  end
end
```


### Fields

You can use fields like page numbers and current dates. A symbol names the field, e.g. `:page` or `:numpages`; a string is written as the field instruction as given, so it can carry switches.

```ruby
docx.p do
  text 'current page is '
  field :page
  text ' / '
  field :numpages
end

docx.p do
  field 'DATE \\@ "yyyy-MM-dd"'
end
```

### Tabs

Tab stops are set per paragraph or list item with `tabs`, an Array of stops: a number is a start-aligned stop at that position in twips; a Hash `{ pos:, val:, leader: }` sets the alignment (`val`, default `start`) and the leader (`leader`, default `none`). `val` accepts `start`, `center`, `end`, `decimal`, `bar`, `num`, `clear`, `left` and `right`; other values raise `Caracal::Errors::InvalidModelError`. `end_tab: true` adds a tab after a text run:

```ruby
docx.p do
  tabs [2880]
  text 'column at 0', end_tab: true
  text 'column at 2880 twips (2in)'
end

docx.p tabs: [2880, 5760] do
  text 'column at 0', end_tab: true
  text 'column at 2in', end_tab: true
  text 'column at 4in'
end

docx.p tabs: [{ pos: 9000, val: :right, leader: :dot }] do
  text 'Chapter 1', end_tab: true
  text '7'
end
```

### Bookmarks

Bookmarks can be added directly to the document or inside paragraph blocks using the `bookmark_start` and `bookmark_end`
methods. Bookmarks can be inserted at the document-level to describe section headings, etc. or inside
of a paragraph block for fine-grained linking. The optional `id` (string or integer) pairs a `bookmark_start` with its
`bookmark_end`; without it, `bookmark_end` closes the most recently opened bookmark.

```ruby
# document-level bookmark
docx.bookmark_start id: 's1', name: 'section1'
docx.h2 'Section Heading'
docx.bookmark_end id: 's1'
docx.p  'Section content.'

# paragraph-level bookmark
docx.h2 'Section Heading'
docx.p do
  text 'Pretend this paragraph has a lot of text and we want to bookmark '
  bookmark_start id: 'p1', name: 'phrase1'
  text 'a single phrase'
  bookmark_end id: 'p1'
  text ' inside the larger block.'
end
```

Bookmarks work in conjunction with internal links.  Please see above.


### Headings

Headings can be added using the `h1`, `h2`, `h3`, `h4`, `h5`, and `h6` methods.  Headings are simply paragraph commands with a specific style set, so anything you can do with a paragraph is available to a heading.

```ruby
docx.h1 'Heading'

docx.h2 do
  text 'Heading with a '
  link 'Link', 'http://www.google.com'
  text '.'
end
```

#### Heading Numbering

`heading_numbering` numbers the headings. `text` is the number's text, with `%1` to `%6` standing for the counters of `h1` to `h6`.

```ruby
docx.heading_numbering do
  h1 fmt: 'decimal', text: '%1.'
  h2 text: '%1.%2', suff: 'tab'
end

docx.heading_numbering h1: { text: '%1.' }, h2: { fmt: 'lowerLetter', text: '%1.%2' }
```

`fmt` is one of `decimal` (default), `decimalZero`, `lowerLetter`, `upperLetter`, `lowerRoman`, `upperRoman`, `ordinal` and `none`. `suff` follows the number: `space` (default), `tab` or `nothing`. Levels not given stay unnumbered.


### Table of Contents

Caracal lists the document's headings in a table of contents. Word offers to update it, including page numbers, when it opens the document; until then each entry shows the placeholder.

```ruby
docx.table_of_contents
# Or, for brevity:
docx.toc

# Both methods accept the same options: legend, start_level, end_level, and placeholder

docx.toc legend: 'Table of contents', start_level: 1, end_level: 3
# or using block form:
docx.toc do
  legend      'Table of contents' # Default is nil
  start_level 1                   # Default is 1 (headings level 1, aka docx.h1 or p style: 'Heading1')
  end_level   3                   # Default is 3 (headings level 3, aka docx.h3 or p style: 'Heading3')
  placeholder '#'                 # Default is '#', shown as page number until the TOC is updated
end
```

A legend appears as a heading in the TOCHeading style above the entries; without a legend there is no heading. `start_level` and `end_level` are heading levels from 1 to 6, with `end_level` equal to or greater than `start_level`.

To start the table of contents on a new page, add `docx.page` before it.

### Rules

Horizontal rules can be added using the `hr` method.  The method accepts several optional parameters for controlling the style of the rule.

```ruby
docx.hr do
  color   '333333'   # sets the color of the line. defaults to auto.
  line    :double    # sets the line style, a Word border style such as single, double or dotted. defaults to single.
  size    8          # sets the thickness of the line. units in 1/8 points. defaults to 4.
  spacing 4          # sets the spacing below the line. units in points. defaults to 1.
  width   2880       # sets the length of the line. units in twips. defaults to the full width.
  align   :center    # places a shorter line. accepts :left, :center and :right. defaults to :center.
  top     120        # sets the spacing above the rule. units in twips.
  bottom  120        # sets the spacing below the rule. units in twips.
  height  60         # sets the exact height of the rule's paragraph. units in twips.
end
```

Without `top`, `bottom` and `height`, a rule takes the spacing and line height of the Normal style.


### Line Breaks

Line breaks can be added via the `br` method inside paragraphs.

```ruby
docx.p do
  text 'This sentence precedes the line break.'
  br
  text 'This sentence follows the line break.'
end
```

Line breaks only work inside paragraph-like commands. If you want to create an empty line between two paragraphs, use an empty paragraph instead.

```ruby
docx.p
```

In justified paragraphs (`align :both`), Word spreads the words of a line that ends in a line break across the whole line. `justify_lines_before_breaks false` leaves such lines at their natural width, as browsers do.

```ruby
docx.justify_lines_before_breaks false
```


### Lists

Ordered lists can be added using the `ol` and `li` methods.  The `li` method basically follows the same rules as the `p` method.

```ruby
docx.ol do
  li 'First item'
  li do
    text 'Second item with a '
    link 'link', 'http://www.google.com'
    text '.'
    br
    text 'This sentence follows a line break.'
  end
end
```

Similarly, unordered lists can be added using the `ul` and `li` methods.

```ruby
docx.ul do
  li 'First item'
  li do
    text 'Second item with a '
    link 'link', 'http://www.google.com'
    text '.'
    br
    text 'This sentence follows a line break.'
  end
end
```

A list item with `bidi true` runs right to left, with its number on the right. `left` moves an item further in, number included; `right` indents its end.

Lists nest up to nine levels deep and mix in any combination; a tenth level raises `Caracal::Errors::InvalidModelError` when it is added. Text added after a nested list renders after it, as an unnumbered paragraph aligned with the item's text, and an item can hold several nested lists.

```ruby
docx.ul do
  li 'First item'
  li 'Second item' do
    ol do
      li 'SubItem 1'
      li 'SubItem 2' do
        ol do
          li 'SubSubItem'
        end
      end
    end
    text 'More about the second item.'
  end
end
```


### List Styles

List styles are defined with the `list_style` command. `type`, `level`, `format` and `value` are required; the other options control the rendering of list items.

*Caracal will automatically define 9 levels of default styles for both ordered and unordered lists.*

```ruby
docx.list_style do
  type    :ordered    # sets the type of list. accepts :ordered or :unordered.
  level   2           # sets the nesting level. 0-based index.
  format  'decimal'   # sets the list style. see OOXML docs for details.
  value   '%3.'       # sets the value of the list item marker. see OOXML docs for details.
  align   :left       # sets the alignment. accepts :left, :center and :right. defaults to :left.
  indent  400         # sets the indention of the marker from the margin. units in twips.
  left    800         # sets the indention of the text from the margin. units in twips.
  start   2           # sets the number at which item counts begin. defaults to 1.
  restart 1           # restarts the numbers after an item of this 1-based level or a higher one; 0 never restarts them. defaults to restarting after any higher level.
end
```


### Images

Images can be added by using the `img` method. The other parameters control the size, style and placement of the asset.

*Caracal will automatically embed the image in the Word document.*

```ruby
docx.img 'https://www.example.com/logo.png' do
  data    File.binread('logo.png')  # the image's raw bytes, used instead of reading the url
  width   396       # sets the image width. units specified in pixels. defaults to the image's own width.
  height  216       # sets the image height. units specified in pixels. defaults to the image's own height.
  ppi     96        # sets the pixels per inch. default is 72.
  align   :right    # controls the justification of the image. default is :left.
  top     10        # sets the top margin. units in points. defaults to 8.
  bottom  10        # sets the bottom margin. units in points. defaults to 8.
  left    10        # sets the left margin. units in points. defaults to 8.
  right   10        # sets the right margin. units in points. defaults to 8.
end
```

*Width and height are read from PNG, JPEG and GIF data; give one of them to scale the image keeping its aspect ratio. Other formats need both. Pixel sizes are converted at `ppi`; without `ppi`, the image's own size uses the density stored in PNG and JPEG files (horizontal for width, vertical for height), else 96.*

Every setting also works as an option:

```ruby
docx.img 'logo.png', data: File.binread('logo.png'), width: 396, height: 216
```

*`data` takes the image's raw bytes, as `File.binread` returns them, and Caracal embeds them unchanged. With `data`, the first argument only names the image.*

#### Anchored Images

Images are placed inline by default. `anchor: true` positions the image freely instead; `top`, `bottom`, `left` and `right` then set the distance to the surrounding text.

```ruby
docx.img 'https://www.example.com/logo.png', width: 120, height: 60, anchor: true do
  x           1440      # horizontal offset in twips. default aligns the image by its align value.
  y           720       # vertical offset in twips. default is the top.
  relative_to :margin   # :page (default), :margin, :column or :paragraph.
  wrap        :square   # :top_and_bottom (default), :square, :none (in front of text) or :behind (behind text).
end
```

`relative_to_x` and `relative_to_y` set the reference per axis. Vertically, `:column` measures from the margin; horizontally, `:paragraph` measures from the column.

### Tables

Tables can be added using the `table` method.  The method accepts several optional parameters to control the layout and style of the table cells.

The `table` command accepts data in the form of a two-dimensional arrays. This corresponds to rows and column cells within those rows.  Each array item can be a string, a Hash of options, a Proc (which will be passed as a block), or a `TableCellModel`.  The command will normalize all array contents into a two-dimensional array of `TableCellModel` instances.

```ruby
docx.table [['Header 1','Header 2'],['Cell 1', 'Cell 2']] do
  border_color   '666666'   # sets the border color. defaults to 'auto'.
  border_line    :single    # sets the border style. defaults to :single. see OOXML docs for details.
  border_size    4          # sets the border width. defaults to 4. units in 1/8 points.
  border_spacing 4          # sets the cell spacing (units in twips) and the spacing around the border (units in points). defaults to 0.
  column_widths  [80, 120]  # sets the column widths. units in twips. defaults to equal shares of the table width.
  repeat_header  1          # sets the number of header rows that is repeated on each page. defaults to 0. header_rows is an alias.
  width          9360       # sets the table width. units in twips. defaults to the sum of column_widths, else the available width.
  align          :center    # :left, :center (default), :right, :start or :end.
  layout         :fixed     # :fixed (default) or :autofit.
  row_height     400        # sets the minimum height of every row. units in twips.
  indent         0          # sets the left indent. units in twips.
  caption        'Table 1'  # adds a caption paragraph above the table.
end
```

*`column_widths` covering every column also sets the table width, unless `width` is given; other columns share the rest of the table width.*

*`layout :autofit` without `width`, `column_widths` or cell widths lets Word size the columns to their contents. Given widths stay the preferred widths.*

Any table-level border option draws all table borders. A table without border options shows its style's borders; the default style has none.

`border_line`, and `line` in a position-specific border or `hr`, accept Word's border styles (`ST_Border`), such as `single`, `double`, `dotted`, `dashed`, `dotDash`, `thick`, `wave` and `none`. Other values raise `Caracal::Errors::InvalidModelError`.

Table borders can be further styled with position-specific options. Caracal supports styling the top, bottom, left, right, inside horizontal, and inside vertical borders with the `border_top`, `border_bottom`, `border_left`, `border_right`, `border_horizontal`, and `border_vertical`, respectively. Options have the same meaning as those set at the table level, and options not given fall back to the table-level ones.

```ruby
docx.table data, border_size: 4 do
  border_top do
    color   '000000'
    line    :double
    size    8
    spacing 2
  end
end
```

Table cells are styled with `cell_style` inside the table's block. It applies the options to the `TableCellModel` instances in its first argument, a cell or an array of cells, and skips options they lack.

*As a convenience, the table provides the methods `rows`, `cols`, and `cells` to facilitate building the first argument.*

The example will style the first row as a header and establish a fixed width for the first column.

```ruby
docx.table [['Header 1','Header 2'],['Cell 1', 'Cell 2']], border_size: 4 do
  cell_style rows[0], bgcolor: '3366cc', color: 'ffffff', bold: true
  cell_style cols[0], width: 6000
end
```

It is possible to merge cells vertically and horizontally using the `rowspan` and `colspan` options in `cell_style` method e.g.

```ruby
docx.table [['11', '1213', '14'], ['21', '22', '23', '24']] do
  cell_style rows[0][0], rowspan: 2
  cell_style rows[0][1], colspan: 2
  cell_style rows[0][2], rowspan: 2
end
```

*Note: content of cells 21 and 24 will disappear*

Rows marked with `cant_split` move to the next page as a whole instead of breaking across a page break. It takes a row or an array of rows.

```ruby
docx.table [['11', '22'], ['14', '25'], ['64', '23']] do
  cant_split rows[1]       # one row
  cant_split rows[1...-1]  # or several
end
```

`row_height` sets the height of a row or an array of rows, at least that high by default or exactly with `rule: :exact`. Without rows, it applies to every row. Units in twips.

```ruby
docx.table [['11', '22'], ['14', '25'], ['64', '23']] do
  row_height 400                         # every row at least 400 twips
  row_height rows[0], 600, rule: :exact  # the first row exactly 600 twips
end
```

#### Table Styles

Table styles take the style options plus conditional formats for parts of the table. A table's `look` selects which parts get them.

```ruby
docx.style id: 'Grid', name: 'grid', type: :table, border_color: '666666' do
  conditional_format type: :firstRow, bold: true, bgcolor: 'cccccc'
  conditional_format type: :band2Horz, bgcolor: 'eeeeee'
end

docx.table data, style: 'Grid' do
  look first_row: true, last_row: true, first_col: true, last_col: true # default false. hband and vband default to true.
end
```

Conditional format types are `wholeTable`, `firstRow`, `lastRow`, `firstCol`, `lastCol`, `band1Horz`, `band2Horz`, `band1Vert`, `band2Vert` and the corner cells `nwCell`, `neCell`, `swCell`, `seCell`. Header and total rows and columns are not banded.

### Table Cells

If your table contains more complex data (multiple paragraphs, images, lists, etc.), you will probably want to instantiate your `TableCellModel` instances directly.  Table cells can contain anything the document can contain, including another table, except page breaks and a table of contents.

```ruby
c1 = Caracal::Core::Models::TableCellModel.new do
  bgcolor 'cccccc'    # sets the background color.
  margins do
    top     100       # sets the top margin. units in twips.
    bottom  100       # sets the bottom margin. units in twips.
    left    100       # sets the left margin. units in twips.
    right   100       # sets the right margin. units in twips.
  end

  p 'This is a sentence above an image.'
  p
  img 'https://www.example.com/logo.png', width: 200, height: 100
end
```

*Background and margins are unset by default, so the table style applies. `margins` also accepts a hash (`margins top: 0, left: 100`), as does `cell_style`; sides not given stay unchanged.*

Word ends every table cell with a paragraph. When a cell's content ends in something else, such as a nested table, Caracal adds an empty paragraph 1pt high.

To display images side-by-side, they need to be laid out horizontally in a table.

```ruby
image_1_cell = Caracal::Core::Models::TableCellModel.new do
  img 'https://www.example.com/logo.png'
end

# a block argument keeps the surrounding scope, e.g. for an ActiveStorage attachment in @image
image_2_cell = Caracal::Core::Models::TableCellModel.new do |cell|
  cell.img @image.filename.to_s, data: @image.download
end

docx.table [[image_1_cell, image_2_cell]]
```


### Nested Tables

Because table cells can contain anything that can be added to the document, **tables can be nested to achieve whatever layout goals you want to achieve**.

```ruby
row1 = ['Header 1', 'Header 2', 'Header 3']
row2 = ['Cell 1', 'Cell 2', 'Cell 3']
row3 = ['Cell 4', 'Cell 5', 'Cell 6']
row4 = ['Footer 1', 'Footer 2', 'Footer 3']
c1 = Caracal::Core::Models::TableCellModel.new margins: { top: 0, bottom: 100, left: 0, right: 200 } do
  table [row1, row2, row3, row4], border_size: 4 do
    cell_style rows[0],  bold: true, bgcolor: '3366cc', color: 'ffffff'
    cell_style rows[-1], bold: true,   bgcolor: 'dddddd'
    cell_style cells[3], italic: true, color: 'cc0000'
    cell_style cells,    size: 18, margins: { top: 100, bottom: 0, left: 100, right: 100 }
  end
end
c2 = Caracal::Core::Models::TableCellModel.new margins: { top: 0, bottom: 100, left: 0, right: 200 } do
  p 'This layout uses nested tables (the outer table has no border) to provide a caption to the table data.'
end

docx.table [[c1,c2]] do
  cell_style cols[0], width: 6000
end
```

### Raw OOXML

`raw_xml` inserts OOXML as given, in the body, a header or footer, or a table cell:

```ruby
# this inserts a paragraph styled as Heading3
docx.raw_xml <<-EOXML
<w:p>
  <w:pPr>
    <w:pStyle w:val="Heading3"/>
    <w:spacing w:before="0" w:after="0"/>
    <w:contextualSpacing/>
    <w:rPr/>
  </w:pPr>
  <w:r>
    <w:rPr/>
    <w:t>My heading</w:t>
  </w:r>
</w:p>
EOXML
```


## Color Themes

Instead of specifying a `color` or `bgcolor` value in your styles or other models, you may use their theme counterparts `theme_color` or `theme_bgcolor`, respectively. This combined with a custom color theme allows the consumers of your DOCX file to switch to their own color theme and have all your styles magically honor them.

`theme_color` and `theme_bgcolor` accept dark1, light1, dark2, light2, accent1 to accent6, hyperlink, visited_hyperlink (or followedHyperlink), text1, background1, text2, background2 and none. Every document includes caracal's default color theme; customize it like so:

```ruby
docx.theme do
  name 'My Color Theme'
  color_dark1   '001122'
  color_light1  'FFFFFF'
  color_accent1 'ff0000'
  color_accent2 '0000ff'
end
```

and use theme colors e.g. like this:

```ruby
docx.p do
  theme_color :accent1
  theme_bgcolor :accent2
  text 'this is red text on a blue background, '
  text 'this run has inverted colors, ', theme_color: :accent2, theme_bgcolor: :accent1
  text 'but this run has not.'
end
```

## Experimental Features

### IFrames

`iframe` copies the body of another Word document into this one when you call it, read from `url` (an http(s) URL or a path) or from `data` (its raw bytes):

```ruby
docx.iframe url: 'https://www.example.com/snippet.docx'
docx.iframe data: File.binread('my/path/to/snippet.docx')
```

Caracal carries over paragraphs, tables and images; they take this document's styles and list numbering. Iframes also work in table cells.

**Only embed documents you trust.** Caracal parses the file you supply and copies its markup into your output, so the embedded document controls part of the result. To keep a small crafted file from expanding into a large one in memory, Caracal refuses an entry of the embedded document that declares or holds more than `Caracal::Core::Models::IFrameModel.max_entry_size` bytes (50MB by default) with an `InvalidModelError`, and stops reading it at that limit. Set it to another number of bytes, or to `nil` to turn the check off. See [Security](#security).


## Template Rendering

Caracal includes [Tilt](https://github.com/jeremyevans/tilt) integration to facilitate its inclusion in other frameworks. Templates ending in `.caracal` contain Caracal commands on the `docx` variable and render to a docx string:

```ruby
Tilt.new('report.docx.caracal').render
```

Rails integration can be added via the [Caracal-Rails](https://github.com/urvin-compliance/caracal-rails) gem.


## Using Variables

Blocks without an argument run on the Caracal object: they see local variables, but not the caller's instance variables or methods. Blocks with an argument keep the caller's scope:

```ruby
Caracal::Document.save 'report.docx' do |docx|
  docx.p @title
  docx.p { |p| p.text helper }
end
```

Alternatively, you may use the `Caracal::View` mixin to create documents, just like [Prawn](https://prawnpdf.org/docs/prawn/2.5.0/Prawn/View.html). Here is a basic example using this mixin:

```ruby
class Export
  include Caracal::View

  def initialize(data = [])
    @data = data
    add_data
  end

  def add_data
    table @data do
      cell_style cells,   size: 22
      cell_style rows[0], size: 24, bold: true
    end
  end
end

# Usage:
Export.new(some_data).save_as("export #{Date.today}.docx")

# Or send from a Rails controller, with the docx MIME type registered (e.g. by Caracal-Rails):
respond_to do |format|
  format.html
  format.docx do
    doc = Export.new(my_data)
    send_data doc.render, filename: doc.name, disposition: :inline, type: Mime::Type.lookup_by_extension(:docx)
  end
end
```

## Filing an Issue

Caracal was written for and tested against Word 2010, 2013, and Office365. It should also open in LibreOffice
with high fidelity.


### Older Versions

If you are using a version of Word that predates 2010, Caracal may or may not work for you. (Probably it won't.)
We don't ever plan to support versions before 2010, but if you choose to embark on that endeavor, we'd be
happy to answer questions and provide what guidance we can. We just won't write any code in that direction.


### Newer Versions

For those using reasonably current versions of Word, please consider the following:

- Before you file an issue, please run the example Caracal project [caracal-example](https://github.com/urvin-compliance/caracal-example) in your development environment and
check the output. It covers the core features.

- If you don't see your issue in the example project's implementation of the same feature, chances are you
made a mistake in your document's syntax or have an environment-specific, non-caracal problem.

- If you do see the same behavior in the example project, you've probably uncovered a variance in the way
your particular permutation of Windows/Word interprets the OOXML.


### How to Work on a Problem

Caracal is essentially an exercise in reverse engineering OOXML output. When developing features, we
typically start by building the simplest Word document we can that includes the desired behavior.
Then, we change the document extension to .zip, extract the archive, and inspect the resulting OOXML.
Finally, we teach the corresponding renderer to output that OOXML.

It's a tedious process, but it's not nearly as tedious as learning the entire OOXML specification.

The downside is Word changes its expectations about OOXML format with each version, so it can be a bit
of a balancing act to get the OOXML structured for acceptance by all supported versions.


## Contributing

1. Fork it ( https://github.com/trade-informatics/caracal/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request


## Why is It Called Caracal?

Because my son likes caracals. :)


## Inspiration

A tip of the hat to the wonderful PDF generation library [Prawn](https://github.com/prawnpdf/prawn).


## License

Copyright (c) 2014 Trade Informatics, Inc

[MIT License](LICENSE.txt)
