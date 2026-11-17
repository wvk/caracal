#### Unreleased

* Changes
  * List levels restart after any higher level, Word's default; `numbering.xml` writes `lvlRestart` only for list styles that set `restart` (upstream #85).
  * The empty paragraph closing a table cell after non-paragraph content, such as a nested table, is 1pt high (upstream #122).

* Enhancements
  * `row_height` sets the height of every row or of given rows, at least or exactly (upstream #119).
  * `bidi true` sets right-to-left direction on paragraphs, list items and styles; list numbers move to the right (upstream #117).
  * `layout :autofit` without widths sizes table columns to their contents (upstream #63).
  * `hr` takes `width`, `align`, `top`, `bottom` and `height` (upstream #128, #138).
  * `page_columns` sets the text in columns; `column_break` continues in the next column (upstream #140).
  * `justify_lines_before_breaks false` leaves justified lines that end in a line break at their natural width (upstream #42).

* Bug fixes
  * Tables in headers and footers take the document's page width; they used US Letter's.
  * `p` and `li` write `keep_lines` and `widow_control`; `left` and `right` indent `p`, `li` and paragraph styles (#18).
  * `toc` writes its heading only when given a `legend`; its error for invalid levels names the range 1 to 6 (#9).
  * A document with an iframe holding images renders more than once, for example `render` and then `save`; the second render raised `NoMethodError` (#4).
  * A list nested ten levels deep raises `Caracal::Errors::InvalidModelError` when it is built, naming the nine-level limit; it raised `NoMethodError` while rendering (#7).

#### v2.0.0

* Breaking changes
  * Require Ruby 3.2 and Tilt 2.0; ActiveSupport is not needed.
  * Headers, footers and the page number appear on the first page. For a different first page, use upstream caracal's API: `header first: true`, `footer first: true` and `page_numbers first_page: false`. A first page without its own header or footer shows the default one.
  * `page_numbers` writes into the document footer; `docx.footer.page_numbers` is removed.
  * `line` is a minimum line height (`lineRule atLeast`). Use `line_rule: :exact` or `:auto` for the previous behaviours.
  * Any border option draws a single ½ pt line by default.
  * Run options override the options of their paragraph.
  * Bookmark `id:` is a key pairing start and end; numeric ids are assigned while rendering. `next_bookmark_id` and `current_bookmark_id` are removed.
  * Images without `width`/`height` use their own size at the file's DPI, else 96 ppi.
  * Media parts are named `media/image-<hash>.<ext>`, hashed from the image URL and, if given, its data.
  * `highlight_color` accepts Word's highlight colour names only.
  * Theme colour names are validated; `visited_hyperlink` is `followedHyperlink`.
  * Invalid custom properties raise `Caracal::Errors::InvalidModelError`.
  * `page_size` raises if the margins don't fit; omitted dimensions and margins keep their current values.
  * Every document contains a theme part.
  * `RelationshipModel` no longer takes `key:`.
  * Fields render as complete complex fields (begin, instruction, separate, end runs); a symbol field name is upcased, so `field :page` writes `PAGE`.
  * Text given to `li` leads the item, ahead of runs and nested lists added in its block.
  * Requires nokogiri 1.16.2 or later and rubyzip 1.1.6 or later; allows rubyzip 3.

* Enhancements
  * Embed TrueType fonts, obfuscated by default (@wvk)
  * Number headings via `heading_numbering` (@wvk)
  * Position anchored images by offset, reference and wrap mode
  * Character styles and `style:` on text runs and links
  * Table styles with conditional formats and banding
  * Table cell `margins` (hash or block); table captions; cell borders and styles; bookmarks and raw XML in table cells
  * First-page headers and footers; document footers; lists in headers and footers
  * Table of contents with legend, levels and `placeholder`; Word updates it on open
  * Color themes
  * `line_rule` for styles, paragraphs and list items
  * Paragraph tabs with position, alignment and leader
  * Nested lists of mixed types, list item alignment
  * Lambdas as document, model and table cell blocks
  * Merged from upstream caracal 1.5.0 and 1.6.0 (@dlauer and contributors):
    * `page_numbers start:` sets the number of the first page
    * `cant_split` keeps table rows from breaking across pages
    * `header_rows`, an alias of `repeat_header`
    * Iframes in table cells
    * Text after a nested list renders after it; an item can hold several nested lists
    * `IFrameModel.max_entry_size` (50MB by default) caps entries read from embedded documents
    * Image part extensions come from the image data, else the URL path; bmp, tif, tiff and svg content types
    * Package entries are written with their size, so rubyzip 3 adds no zip64 records that LibreOffice 7.4 and older reject
    * Security section in the README

* Bug Fixes
  * Image and iframe sources are read with `URI.open` for http(s) URLs and `File.binread` otherwise, never `Kernel#open`, so a source starting with `|` no longer runs as a shell command (from upstream 1.5.0)
  * Control characters XML doesn't allow are removed from text, links, captions, the TOC and custom properties (from upstream 1.5.0)
  * Custom properties, tabs, TOC, iframes from URLs and saving under the default file name no longer raise
  * Header and footer blocks and `align:` paragraphs render
  * Row and column spans merge the right cells; cell widths add up to the table width
  * Highlight colours, link `underline false` and `hr` defaults render
  * Unique bookmark and drawing ids; images with the same URL and different data stay apart
  * Valid OOXML for page margins, anchored images, theme colours and run properties

#### v1.7.2

* Enhancements
  * Add view mixin to easily access variables when generating documents (@goulvench)

#### v1.7.1

* Enhancements
  * Improve header alignment (@goulvench)
  * Add table of contents (@goulvench)

#### v1.6.1

* Enhancements
  * Allow images in table cells (@goulvench)
  * Add customisable page headers (@brutu33)
  * Update dependency to use Bundler 2 (@goulvench)

#### v1.5.1

* Enhancements
  * Allow setting explicit column widths for tables (@martinsp)
  * Allow Rubyzip 2.0 (@geoffharcourt)
  * Added ability to repeat table headers (@AliceVerner)
  * Add `.keep_next` paragraph property (@benjaminketron)
* Bug Fixes
  * Fix cols method in table_model (@AliceVerner)

#### v1.4.2

* Bug Fixes
  * Fix image tag ignoring the data option (@yholkamp)

#### v1.4.1

* Bug Fixes
  * Corrected rowspan logic to handle all cases. (@martinsp)


#### v1.4.0

* Enhancements
  * Changed `file_name` method to accept absolute and relative paths. (@jdugan)
  * Added instance save method so documents can be created via commands instead of blocks, if desired. (@jdugan)
  * Removed extra paragraph tag inserted after tables; added logic to ensure final tag of table cells is always a paragraph. (@jdugan)


#### v1.3.0

* Enhancements
  * Added proper text highlighting. Colors are limited so we left :bgcolor option. (@rmarone)
  * Added bookmarks and internal links. (@rmarone)


#### v1.2.0

* Enhancements
  * Added colspan and rowspan functionality to table styling feature. (@ViktorKopychko)


#### v1.1.2

* Enhancements
  * Added font size options for page numbers. (@cfacello)


#### v1.1.1

* Enhancements
  * Added character styles. (@xerespm)


#### v1.1.0

* Enhancements
  * Corrected how renderers output namespaced nodes to ensure jruby compliance. (HUGE thank you to @henrychung for researching and implementing this).


#### v1.0.13

* Bug Fixes
  * Corrected bug where lists were no longer multi-line. (@jdugan h/t @StochasticSpring).


#### v1.0.12

* Bug Fixes
  * Removed unintended use of Active Support method in footer renderer. (@jdugan).


#### v1.0.11

* Bug Fixes
  * Cleaned up experimental feature for iframes. (@jdugan).


#### v1.0.10

* Enhancements
  * Added experimental feature for iframes. (@jdugan).


#### v1.0.8

* Enhancements
  * Added indentation controls to paragraph commands (@avolochnev).


#### v1.0.7

* Enhancements
  * Added an :orientation option to :page_size so print jobs work as expected (@jdugan h/t @swedishpotato).


#### v1.0.6

* Bug Fixes
  * Changed Paragraph and Table Cell Models slightly to allow syntax flexibility with respect to options (@jdugan).


#### v1.0.5

* Enhancements
  * Added vertical alignment (@ykonovets).


#### v1.0.4

* Enhancements
  * Changed tilt dependency to be less restrictive (@jdugan).


#### v1.0.3

* Enhancements
  * Added custom properties (@davidtolsma).
  * Added page breaks to paragraph model sub-functions (@jdugan).


#### v1.0.2

* Enhancements
  * Corrected image markup to support Word 2007 (@Alnoroid).


#### v0.3.0

* Deprecations
  * The :style attribute is no longer allowed on text and link commands. Use :font, :size, etc. instead (@jdugan).


#### v0.2.1

* Enhancements
  * Added :caps attribute to paragraph styles (@jensljungblad).
  * Change table model to allow TableCellModel to be subclassed (@gh4me).


#### v0.2.0

* Enhancements
	* Implemented true line breaks within paragraphs (@Linuus).
	* Converted paragraph command to accept/allow blank content (@Linuus).
	* Allowed :top and :bottom attributes to be set on default paragraph style (@jdugan).


* Deprecations
	* Line breaks are no longer allowed at the document level. Use blank paragraphs instead (@jdugan).


#### v0.1.x

* Enhancements
	* Initial commits. (@jdugan)
