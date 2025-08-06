# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Perl-based project for audio transcription and alignment analysis. The codebase focuses on processing TextGrid files (from Praat software) and includes machine learning utilities for speech processing tasks.

## Core Components

### Primary Libraries
- **TextGrid.pm**: Comprehensive TextGrid file parser and manipulation library
  - Handles Praat TextGrid format reading/writing
  - Provides Range, Node, NodeChain, and TextGrid classes
  - Supports tier manipulation, time interval processing, and data export
  - Key functions: `read()`, `addTier()`, `getTier()`, `flash()` (save)

- **sml.pm**: Machine learning utilities library
  - Statistical functions and data preprocessing
  - Model evaluation metrics (accuracy, RMSE, confusion matrix)
  - Algorithm implementations (linear regression, logistic regression, decision trees)
  - Cross-validation and train/test splitting utilities

### Main Script
- **textgrid.pl**: Example script demonstrating TextGrid manipulation
  - Loads TextGrid files and extracts IPU (Inter-Pausal Unit) tiers
  - Creates new tiers and nodes programmatically
  - Shows typical workflow for speech analysis tasks

## Data Structure

### Training/Validation Data
- `data/training/` and `data/validation/` contain:
  - Audio files (.mp3)
  - TextGrid annotation files (.TextGrid)
  - Alignment files (.align) with transcription text
  - HTML files (numbered 01.html to 12.html) containing segmented content

### File Relationships
- TextGrid files contain time-aligned annotations
- Alignment files contain raw transcription text
- Audio files provide the source material
- HTML files appear to contain processed/segmented versions

## Development Commands

### Running Scripts
```bash
# Execute main TextGrid processing script
perl textgrid.pl

# Process TextGrid files directly with Perl modules
perl -MTextGrid -e "my \$tg = new TextGrid('file.TextGrid'); print \$tg->toString();"
```

### External Tools
- **praat**: Praat executable for advanced phonetic analysis
- The project includes a precompiled Praat binary for Linux x86_64

## Architecture Notes

### TextGrid Processing Workflow
1. Load TextGrid files using `TextGrid->new()` or `validate_textgrid_path()`
2. Extract specific tiers (e.g., 'IPU' tier for speech units)
3. Manipulate time ranges and annotations using Range and Node objects
4. Create new tiers and add annotations
5. Save modified TextGrid files using `flash()` method

### Key Classes and Methods
- **Range**: Time interval representation with start/end times
- **Node**: Annotation with value and time range
- **NodeChain**: Collection of nodes representing a tier
- **TextGrid**: Container for multiple tiers with file I/O operations

### Machine Learning Integration
- The sml.pm library provides algorithms compatible with both Perl arrays and MXNet NDArrays
- Supports common ML workflows: data preprocessing, model training, evaluation
- Includes specialized functions for audio/speech analysis contexts

## Important Notes
- TextGrid files use specific encoding (UTF-8/UTF-16) - the library handles this automatically
- Time values are handled with configurable precision trimming
- The codebase supports both short-text and long-text TextGrid formats
- All file paths should be absolute when working with the TextGrid library