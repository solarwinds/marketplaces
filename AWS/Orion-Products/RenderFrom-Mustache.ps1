#requires -module Poshstache
param 
(
    [string] $TemplatePath,
    [string] $Parameters,
    [string] $OutputFile
)

# added replace due to Stubble using WebUtility.HtmlEncode for encoding tokens
(ConvertTo-PoshstacheTemplate -InputFile $TemplatePath -ParametersObject $Parameters) -replace '&amp;', '&' -replace '&#174;', '®' -replace '&#39;', '''' `
| Out-File $OutputFile -Force -Encoding "UTF8"
