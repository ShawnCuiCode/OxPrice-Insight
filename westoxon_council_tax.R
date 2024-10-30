# ------------------------------------------------------------
# Task: Extract and Process Council Tax Data from a PDF
# Purpose: Extract data tables from a PDF document, clean and format them,
#          and then save the result to a CSV file.
# Steps:
#   1. Read and extract tables from the specified PDF file.
#   2. Initialize field names for the final dataframe.
#   3. Loop through each extracted table to clean and format data.
#   4. Handle parish/town column naming and format band columns.
#   5. Merge cleaned data into a final dataframe and save it as a CSV.
# ------------------------------------------------------------

# Load necessary libraries
library(tabulizer)
library(dplyr)

# Specify the path to the PDF file
pdf_file <- "./wodc-council-tax-charges-2024-to-2025.pdf"

# Extract tables from all pages of the PDF file
tables <- extract_tables(pdf_file, pages = "all", guess = TRUE)

# Initialize column names for the final dataframe
fieldnames <- c('name', 'Council', 'Band A (6/9)', 'Band B (7/9)',
                'Band C (8/9)', 'Band D (9/9)', 'Band E (11/9)',
                'Band F (13/9)', 'Band G (15/9)', 'Band H (18/9)')

# Create an empty dataframe with the specified column names
final_df <- data.frame(matrix(ncol = length(fieldnames), nrow = 0))
colnames(final_df) <- fieldnames

# Assume the 'Council' column value for all rows is 'West Oxfordshire District Council'
council_name <- 'West Oxfordshire District Council'

# Loop through each extracted table to process and clean the data
for (i in seq_along(tables)) {
  table <- tables[[i]]
  # Convert the table into a dataframe
  df <- as.data.frame(table, stringsAsFactors = FALSE)

  # Skip if the table is empty
  if (nrow(df) == 0) {
    next
  }

  # Set the first row as column names
  colnames(df) <- df[1, ]
  df <- df[-1, ]  # Remove the first row

  # Remove extra spaces from column names and data
  colnames(df) <- trimws(colnames(df))
  df <- df %>% mutate(across(everything(), ~ trimws(.)))

  # Rename the 'Parish/Town' column to 'name'
  if ('Parish/Town' %in% colnames(df)) {
    df <- df %>% rename(name = 'Parish/Town')
  } else if ('Parish' %in% colnames(df)) {
    df <- df %>% rename(name = 'Parish')
  } else {
    # If no appropriate column is found, skip this table
    next
  }

  # Add the 'Council' column
  df$Council <- council_name

  # Rename the band columns to match the specified fieldnames
  band_columns <- colnames(df)[grepl("^Band", colnames(df))]
  band_mapping <- c(
    'Band A' = 'Band A (6/9)',
    'Band B' = 'Band B (7/9)',
    'Band C' = 'Band C (8/9)',
    'Band D' = 'Band D (9/9)',
    'Band E' = 'Band E (11/9)',
    'Band F' = 'Band F (13/9)',
    'Band G' = 'Band G (15/9)',
    'Band H' = 'Band H (18/9)'
  )

  # Apply the column renaming
  df <- df %>% rename_at(vars(band_columns), ~ band_mapping[.])

  # Select and arrange columns to match the specified fieldnames
  df <- df %>% select(all_of(fieldnames))

  # Append the cleaned dataframe to the final dataframe
  final_df <- bind_rows(final_df, df)
}

# Save the final dataframe to a CSV file
output_csv <- "./wodc_council_tax_data.csv"
write.csv(final_df, output_csv, row.names = FALSE)

cat("Data successfully saved to", output_csv, "\n")