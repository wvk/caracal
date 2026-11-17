// Validates Word documents with the Open XML SDK, the validator Microsoft
// ships for Office files. Arguments are .docx files or directories, which
// are searched recursively. Exits 1 when a document has errors, 2 when
// there is nothing to validate.
//
// OOXML_FORMAT_VERSION picks the Office version to validate against
// (Office2007 ... Office2021, Microsoft365); it defaults to Microsoft365.

using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Validation;

var version = Enum.Parse<FileFormatVersions>(
    Environment.GetEnvironmentVariable("OOXML_FORMAT_VERSION") ?? "Microsoft365");
var validator = new OpenXmlValidator(version);

var files = args
    .SelectMany(arg => Directory.Exists(arg)
        ? Directory.EnumerateFiles(arg, "*.docx", SearchOption.AllDirectories)
        : [arg])
    .Order(StringComparer.Ordinal)
    .ToList();

if (files.Count == 0)
{
    Console.Error.WriteLine("No .docx files to validate.");
    return 2;
}

var invalid = 0;

foreach (var file in files)
{
    List<string> errors;

    // Errors refer to parts of the package, so they are formatted while
    // the document is open.
    try
    {
        using var document = WordprocessingDocument.Open(file, false);
        errors = validator.Validate(document)
            .Select(error => $"  {error.Part?.Uri} {error.Path?.XPath}\n    {error.ErrorType}: {error.Description}")
            .ToList();
    }
    catch (Exception e)
    {
        errors = [$"  cannot be opened: {e.Message}"];
    }

    if (errors.Count == 0) continue;

    invalid++;
    Console.WriteLine(file);
    errors.ForEach(Console.WriteLine);
}

Console.WriteLine($"{files.Count - invalid} of {files.Count} documents valid for {version}.");

return invalid == 0 ? 0 : 1;
