# CPC Classification Ingestion Guide

## Purpose
Describe how to obtain, parse, and use the Cooperative Patent Classification (CPC) scheme for use in your Rails application.

## Source
The authoritative source for the CPC scheme is:
- [CPC Scheme and Definitions Bulk Download](https://www.cooperativepatentclassification.org/cpcSchemeAndDefinitions/bulk)
- Download the latest XML (recommended for parsing):
  - https://www.cooperativepatentclassification.org/cpcSchemeAndDefinitions/bulk/cpc-scheme.xml

## Steps

### 1. Download the CPC Scheme XML
You can download the latest scheme manually or via script:

```sh
curl -o cpc-scheme.xml https://www.cooperativepatentclassification.org/cpcSchemeXML/cpc-scheme.xml
```

### 2. Parse the XML in Ruby
Use Nokogiri to parse the XML and extract class codes and descriptions.

#### Example script (lib/tasks/parse_cpc.rake):
```ruby
require 'nokogiri'

namespace :cpc do
  desc 'Parse CPC scheme XML and print class codes/descriptions'
  task :parse_scheme, [:xml_path] => :environment do |t, args|
    xml_path = args[:xml_path] || 'cpc-scheme.xml'
    doc = Nokogiri::XML(File.read(xml_path))
    doc.xpath('//classification-item').each do |item|
      symbol = item.at_xpath('classification-symbol')&.text
      title = item.at_xpath('classification-title/title-part')&.text
      puts "#{symbol}: #{title}" if symbol && title
    end
  end
end
```

### 3. Ingest into Your App
- Store the parsed codes/descriptions in your database for fast lookup.
- Optionally, create a model (e.g., `CpcClass`) to represent the hierarchy.
- Add search/autocomplete UI for users.

### 4. Keep Data Up to Date
- Set up a periodic task to re-download and re-parse the XML as the scheme evolves.

## References
- [CPC Scheme and Definitions](https://www.cooperativepatentclassification.org/cpcSchemeAndDefinitions.html)
- [CPC XML Download](https://www.cooperativepatentclassification.org/cpcSchemeXML/cpc-scheme.xml)
- [USPTO Open Data](https://data.uspto.gov/home)

---

This approach ensures you always have the latest, authoritative CPC class codes available for your Rails application and AI workflows.
