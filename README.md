# Compare-Csv

## Prerequisites
None

## Synopsis
Use this script to compare two (2) seperate CSV spreadsheets with one specific header or "property".

## Description

One example is you have your `SourceFile` with a list of computer names and associated serial numbers, and you have a `CompareFile` with a list of just computer names (from SCCM for example) and you need the serial numbers for that specific group.

## Parameters
- SourceFile
File with data you need to compare against. This should be the file with the most information or information that is absent in the other CSV File. **MUST** be CSV format.

- CompareFile
File with data you need to compare with. This should be the file with information that is also present in the `SourceFile`. **MUST** be CSV format.

- Destination
File that will contain the resulting comparison. **MUST** be in CSV format.

- SourceHeader
Header or Property that you are comparing to in the `SourceFile`

- CompareHeader
Header or Property that you are using to compare in the `CompareFile`

## Examples
`Compare-CSV -SourceFile .\CompNameAndSN.csv -CompareFile .\SCCMCollection.csv -Destination .\ComparedSCCM.csv -SourceHeader "Device Name" -CompareHeader "Computer Name"`