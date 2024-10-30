# ------------------------------------------------------------
# File: oxford_house_price_analysis.R
# Author: Shawn Cui
# Course: COMP6037 Foundations of Data Analytics
# Assignment: Coursework 1 (House Prices and Council Tax Analysis)
# Date: 30 Sep 2024
# Purpose: This script performs data analysis on house prices and council tax
#          data in Oxfordshire, following 3NF and using SQL queries in R.
# ------------------------------------------------------------

# Load necessary libraries
library(DBI)

# Connect to db
conn <- dbConnect(RSQLite::SQLite(), "./oxfordshire_data.db")

# ------------------------------------------------------------
# Task 3
# Function: calculate_avg_price_for_two_years
# Purpose: Calculate the average house price for a given ward in a specific district over two years.
# Inputs:
#   - conn: Database connection object
#   - district_name: District to search within (e.g., 'City of Oxford', 'Cherwell')
#   - ward_name: Ward within the district to analyze
#   - year_1: The first year to include in the calculation (e.g., '2021')
#   - year_2: The second year to include in the calculation (e.g., '2022')
# Output: A data frame showing the average price for the specified ward over two years
# ------------------------------------------------------------

calculate_avg_price_for_two_years <- function(conn, district_name, ward_name, year_1, year_2) {

  # SQL query to calculate the average house price over two years for a given ward
  avg_price_query <- sprintf("
    SELECT wards.name as ward_name,
           AVG(price) as avg_price
    FROM house_prices
    JOIN wards ON wards.id = house_prices.ward_id
    JOIN districts ON districts.id = wards.district_id
    WHERE districts.name = '%s'
      AND wards.name = '%s'
      AND strftime('%%Y', date) IN ('%s', '%s')
    GROUP BY wards.name
  ", district_name, ward_name, year_1, year_2)

  # Execute the query
  result <- dbGetQuery(conn, avg_price_query)

  # Check if the result is empty and return a message if no data is found
  if (nrow(result) == 0) {
    message <- paste("No data found for ward:", ward_name, "in district:", district_name)
    return(data.frame(ward_name = ward_name, avg_price = NA, message = message))
  } else {
    return(result)  # Return the result with average price
  }
}

# Example usage:
result <- calculate_avg_price_for_two_years(conn, 'Oxford', 'Barton and Sandhills', '2022', '2023')
print(result)


# ------------------------------------------------------------
# Task 4
# Function: find_highest_price_ward
# Purpose: Identify the ward in a given district with the highest house price in a specific quarter of a year.
# Input:
#   - conn: Database connection object
#   - district_name: Name of the district to filter by (e.g., 'City of Oxford', 'Cherwell')
#   - quarter_year: Specific quarter and year to filter by (e.g., '2021-03' for Mar 2021)
# Output: A data frame containing the ward name and the highest house price for the given criteria
# ------------------------------------------------------------

find_highest_price_ward <- function(conn, district_name, quarter_year) {
  highest_price_query <- sprintf("
    SELECT wards.name as ward_name,
           MAX(price) as max_price
    FROM house_prices
    JOIN wards ON wards.id = house_prices.ward_id
    JOIN districts ON districts.id = wards.district_id
    WHERE districts.name = '%s'
      AND strftime('%%Y-%%m', date) = '%s'
    GROUP BY wards.name
    HAVING MAX(price) = (
      SELECT MAX(price)
      FROM house_prices
      JOIN wards ON wards.id = house_prices.ward_id
      JOIN districts ON districts.id = wards.district_id
      WHERE districts.name = '%s'
        AND strftime('%%Y-%%m', date) = '%s'
    )
  ", district_name, quarter_year, district_name, quarter_year)

  result <- dbGetQuery(conn, highest_price_query)

  if (nrow(result) == 0) {
    message <- paste("No data found for district:", district_name, "in quarter:", quarter_year)
    return(data.frame(ward_name = NA, max_price = NA, message = message))
  } else {
    return(result)
  }
}

# Example usage:
result <- find_highest_price_ward(conn, 'Oxford', '2022-03')
print(result)

# ------------------------------------------------------------
# Task 5
# Function: calculate_average_council_tax
# Purpose: Calculate the average council tax charge for a specific town in a given district across three bands of properties.
# Input:
#   - conn: Database connection object
#   - town_name: Name of the town to filter by (e.g., 'Banbury')
#   - district_name: Name of the district to filter by (e.g., 'Cherwell')
#   - bands: A character vector of three bands to include in the average calculation (e.g., c("A", "B", "C"))
# Output: A data frame containing the town name, district name, and the calculated average council tax for the given bands.
# ------------------------------------------------------------

calculate_average_council_tax <- function(conn, town_name, district_name, bands) {
  # Check that exactly three bands are provided
  if (length(bands) != 3) {
    stop("Please provide exactly three bands.")
  }

  average_tax_query <- sprintf("
    SELECT parishes.name AS town_name,
           districts.name AS district_name,
           ROUND((AVG(council_tax_rates.band_%s) +
                  AVG(council_tax_rates.band_%s) +
                  AVG(council_tax_rates.band_%s)) / 3, 2) AS average_council_tax
    FROM council_tax_rates
    JOIN parishes ON parishes.id = council_tax_rates.parish_id
    JOIN districts ON districts.id = parishes.district_id
    WHERE parishes.name = '%s'
      AND districts.name = '%s'
  ", tolower(bands[1]), tolower(bands[2]), tolower(bands[3]), town_name, district_name)

  result <- dbGetQuery(conn, average_tax_query)

  if (nrow(result) == 0) {
    message <- paste("No data found for town:", town_name, "in district:", district_name)
    return(data.frame(town_name = NA, district_name = NA, average_council_tax = NA, message = message))
  } else {
    return(result)
  }
}

# Example usage:
result <- calculate_average_council_tax(conn, 'Banbury', 'Cherwell', c("A", "B", "C"))
print(result)

# ------------------------------------------------------------
# Task 6
# Function: calculate_council_tax_difference
# Purpose: Calculate the difference in council tax charges for a specific band between two towns within the same district.
# Input:
#   - conn: Database connection object
#   - district_name: Name of the district to filter by (e.g., 'Cherwell')
#   - town1: Name of the first town to compare (e.g., 'Barford')
#   - town2: Name of the second town to compare (e.g., 'Bicester')
#   - band: Property band to filter by (e.g., 'A', 'B', 'C')
# Output: A data frame containing the names of the two towns, the specified district, and the calculated tax difference for the given band.
# ------------------------------------------------------------

calculate_council_tax_difference <- function(conn, district_name, town1, town2, band) {
  tax_difference_query <- sprintf("
    SELECT
      p1.name AS town1_name,
      p2.name AS town2_name,
      d.name AS district_name,
      (c2.band_%s - c1.band_%s) AS tax_difference
    FROM council_tax_rates c1
    JOIN parishes p1 ON c1.parish_id = p1.id
    JOIN council_tax_rates c2 ON c2.parish_id = p2.id
    JOIN parishes p2 ON p2.id = c2.parish_id
    JOIN districts d ON d.id = p1.district_id
    WHERE d.name = '%s'
      AND p1.name = '%s'
      AND p2.name = '%s'
  ", tolower(band), tolower(band), district_name, town1, town2)

  result <- dbGetQuery(conn, tax_difference_query)

  if (nrow(result) == 0) {
    message <- paste("No data found for the towns:", town1, "and", town2, "in district:", district_name)
    return(data.frame(town1_name = NA, town2_name = NA, district_name = NA, tax_difference = NA, message = message))
  } else {
    return(result)
  }
}

# Example usage:
result <- calculate_council_tax_difference(conn, 'Cherwell', 'Barford', 'Bicester', 'A')
print(result)

# ------------------------------------------------------------
# Task 7
# Function: find_lowest_council_tax_town
# Purpose: Identify the town in a given district with the lowest council tax charges for a specific property band.
# Input:
#   - conn: Database connection object
#   - district_name: Name of the district to filter by (e.g., 'Cherwell')
#   - band: Property band to filter by (e.g., 'A', 'B', 'C')
# Output: A data frame containing the town name and the lowest council tax charges for the given criteria
# ------------------------------------------------------------

find_lowest_council_tax_town <- function(conn, district_name, band) {
  lowest_tax_query <- sprintf("
    SELECT p.name as town_name,
           d.name as district_name,
           c.band_%s as tax_amount
    FROM council_tax_rates c
    JOIN parishes p ON c.parish_id = p.id
    JOIN districts d ON d.id = p.district_id
    WHERE d.name = '%s'
      AND c.band_%s IS NOT NULL
    ORDER BY c.band_%s ASC
    LIMIT 1
  ", tolower(band), district_name, tolower(band), tolower(band))

  result <- dbGetQuery(conn, lowest_tax_query)

  if (nrow(result) == 0) {
    message <- paste("No data found for district:", district_name, "in band:", band)
    return(data.frame(town_name = NA, district_name = NA, tax_amount = NA, message = message))
  } else {
    return(result)
  }
}

# Example usage:
result <- find_lowest_council_tax_town(conn, 'Cherwell', 'B')
print(result)

# Disconnect from the database
dbDisconnect(conn)


# =============================================================================
# Task: Process HPSSA Dataset
# Goal: Clean, transform, and prepare the Oxfordshire HPSSA data from Excel
#       for further analysis and insertion into the SQL database.
# Steps:
#   - Step 1: Read the dataset from Excel file
#   - Step 2: Remove unnecessary rows and columns
#   - Step 3: Transform the dataset (handle missing values and column names)
#   - Step 4: Prepare and store clean data in a SQL database for analysis
# =============================================================================

# Load necessary libraries
library(readr)
library(RSQLite)
library(readxl)

# Read the Excel file and select the sheet
table_1a <- read_excel("hpssa_data.xls", sheet = "1a")

# Remove rows with NA values
table_1a <- na.omit(table_1a)

# Display structure of the data
str(table_1a)

# Set the first row as column names and remove it from the data
colnames(table_1a) <- table_1a[1, ]
table_1a <- table_1a[-1, ]

# Drop columns that are not needed
table_1a <- table_1a[ , -c(1, 3)]

# Filter the data to only include specific districts in Oxfordshire
districts <- c("Oxford", "Cherwell", "South Oxfordshire", "Vale of White Horse", "West Oxfordshire")
oxfordshire_data <- table_1a[table_1a$`Local authority name` %in% districts, ]

# Clean up column names by removing text and updating dates
colnames(oxfordshire_data) <- gsub("Year ending ", "", colnames(oxfordshire_data))

# Function to convert a month and year into a "YYYY-MM-DD" format
convert_to_date <- function(month_year) {
  parts <- strsplit(month_year, " ")[[1]]
  month <- parts[1]
  year <- parts[2]

  last_day <- switch(month, "Mar" = "03-31", "Jun" = "06-30", "Sep" = "09-30", "Dec" = "12-31", NA)
  return(paste(year, last_day, sep = "-"))
}

# Apply date conversion to the appropriate columns
date_columns <- colnames(oxfordshire_data)[3:ncol(oxfordshire_data)]
new_date_columns <- sapply(date_columns, convert_to_date)
colnames(oxfordshire_data)[3:ncol(oxfordshire_data)] <- new_date_columns

# Verify the column names after conversion
print(colnames(oxfordshire_data))

# Export the cleaned data to a CSV file
write.csv(oxfordshire_data, file = "./oxfordshire_data.csv", row.names = TRUE)

# Establish a connection to the SQLite database
conn <- dbConnect(RSQLite::SQLite(), "./oxfordshire_data.db")

# Create the districts table
dbExecute(conn, "
CREATE TABLE districts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
);
")

# Create the wards table with a foreign key to the districts table
dbExecute(conn, "
CREATE TABLE wards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  district_id INTEGER,
  name TEXT NOT NULL,
  FOREIGN KEY (district_id) REFERENCES districts(id)
);
")

# Create the house_prices table with a foreign key to the wards table
dbExecute(conn, "
CREATE TABLE house_prices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ward_id INTEGER,
  date DATE,
  price NUMERIC,
  FOREIGN KEY (ward_id) REFERENCES wards(id)
);
")

# Get the unique districts from the Oxfordshire data
unique_districts <- unique(oxfordshire_data$`Local authority name`)
print(unique_districts)

# Insert each district into the districts table if not already present
for (authority in unique_districts) {
  exists <- dbGetQuery(conn, paste("SELECT COUNT(*) FROM districts WHERE name = '", authority, "';"))

  if (exists[1, 1] == 0) {
    dbExecute(conn, paste0("INSERT INTO districts (name) VALUES ('", authority, "');"))
  }
}

# Query the inserted districts
districts <- dbGetQuery(conn, "SELECT * FROM districts;")
print(districts)

# Match ward names with their respective district IDs
ward_names <- oxfordshire_data$`Ward name`
district_names <- oxfordshire_data$`Local authority name`
district_ids <- districts$id[match(district_names, districts$name)]

# Create and insert the ward data into the wards table
ward_data <- data.frame(district_id = district_ids, name = ward_names)
dbWriteTable(conn, "wards", ward_data, append = TRUE, row.names = FALSE)

# Query the inserted wards
wards_data <- dbGetQuery(conn, "SELECT * FROM wards")
print(wards_data)

# Get the number of rows in the data frame
num_rows <- nrow(oxfordshire_data)
print(num_rows)

# Loop through the data to insert house price information
for (i in 1:num_rows) {
  ward_name <- oxfordshire_data$`Ward name`[i]
  ward_name <- gsub("'", "''", ward_name)

  ward_id_query <- sprintf("SELECT id FROM wards WHERE name = '%s'", ward_name)
  ward_id <- dbGetQuery(conn, ward_id_query)$id

  for (j in 3:ncol(oxfordshire_data)) {
    date <- colnames(oxfordshire_data)[j]
    price <- as.numeric(oxfordshire_data[i, j])

    if (!is.na(price)) {
      insert_query <- sprintf("INSERT INTO house_prices (ward_id, date, price) VALUES (%d, '%s', %f)",
                              ward_id, date, price)
      dbExecute(conn, insert_query)
    }
  }
}

# Query the house_prices table to confirm data insertion
house_prices <- dbGetQuery(conn, "SELECT * FROM house_prices")
print(house_prices)

dbDisconnect(conn)


# =============================================================================
# Task: Process PPD Dataset
# Goal: Clean, transform, and prepare the Price Paid Data (PPD) for further
#       analysis and insertion into the SQL database.
# Steps:
#   - Step 1: Read the dataset from CSV file
#   - Step 2: Select relevant columns (price_paid, deed_date, and district)
#   - Step 3: Clean the data (standardize district names, replace special characters)
#   - Step 4: Insert the cleaned data into SQL database table `house_sales`
# =============================================================================

# Read the CSV file into a dataframe
ppd_table <- read.csv("./ppd_data.csv")

# Take a look at the first few rows of the data
head(ppd_table)

# Check the structure of the data to understand the types of each column
str(ppd_table)

# Select only the columns we care about: price_paid, deed_date, and district
ppd_table_clean <- ppd_table[, c("price_paid", "deed_date", "district")]

# Check the first few rows of the filtered data
head(ppd_table_clean)

# This function turns each word to title case, but keeps "of" in lowercase
toTitleCase <- function(x) {
  s <- strsplit(tolower(x), " ")[[1]]  # Break the string into words and make everything lowercase
  # Keep "of" lowercase, but capitalize the first letter of other words
  s <- ifelse(s == "of", "of", paste(toupper(substring(s, 1, 1)), substring(s, 2), sep = ""))
  return(paste(s, collapse = " "))
}

# This function replaces hyphens with spaces and uses the title case function to format names
process_names <- function(name) {
  # Replace hyphens with spaces
  name <- gsub("-", " ", name)
  # Apply title case while keeping "of" lowercase
  return(toTitleCase(name))
}

# Apply the name processing function to the district column to clean it up
ppd_table_clean$district <- sapply(ppd_table_clean$district, process_names)

# Check the cleaned-up result
head(ppd_table_clean)

# Create the table for house sales if it doesn't exist yet
dbExecute(conn, "
  CREATE TABLE IF NOT EXISTS house_sales (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    price_paid INTEGER,
    deed_date TEXT,
    district_id INTEGER,
    FOREIGN KEY (district_id) REFERENCES districts(id)
  )
")

# Loop through each row of the cleaned PPD data
for (i in 1:nrow(ppd_table_clean)) {
  # Find the corresponding local authority ID based on the district name
  district_name <- ppd_table_clean$district[i]
  query <- sprintf("SELECT id FROM districts WHERE name = '%s'", district_name)
  district_id <- dbGetQuery(conn, query)$id

  # If no match is found, print a message
  if (length(district_id) == 0) {
    print(paste("No match found for district:", district_name))
  } else {
    # Insert the house sale record into the database
    insert_query <- sprintf(
      "INSERT INTO house_sales (price_paid, deed_date, district_id) VALUES (%d, '%s', %d)",
      ppd_table$price_paid[i],
      ppd_table$deed_date[i],  # Date format: 'YYYY-MM-DD'
      district_id
    )
    dbExecute(conn, insert_query)
  }
}

# Check the house_sales table to make sure everything got inserted correctly
house_sales <- dbGetQuery(conn, "SELECT * FROM house_sales")
print(house_sales)

# =============================================================================
# Task: Process Council Tax Dataset
# Goal: Clean, transform, and insert council tax data into the SQL database,
#       linking each parish to its corresponding district and managing council tax rates.
# Steps:
#   - Step 1: Set up 'parishes' and 'council_tax_rates' tables in the SQL database.
#   - Step 2: Define relationships between tables ('parishes' linked to 'districts').
#   - Step 3: Loop through each council tax data file, read and clean the data,
#             and insert it into the database with necessary relationships.
# =============================================================================

# Create 'parish' table to store parish information and relate to 'districts'
dbExecute(conn, "
  CREATE TABLE IF NOT EXISTS parishes (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name TEXT,
    district_id INTEGER,
    FOREIGN KEY (district_id) REFERENCES districts(id)
  )
")

# Create 'council_tax_rates' table if it doesn't exist
dbExecute(conn, "
  CREATE TABLE IF NOT EXISTS council_tax_rates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    parish_id INTEGER,
    band_a REAL,
    band_b REAL,
    band_c REAL,
    band_d REAL,
    band_e REAL,
    band_f REAL,
    band_g REAL,
    band_h REAL,
    FOREIGN KEY (parish_id) REFERENCES parish(id)
  )
")

# Function to process council tax data files and insert them into the database
process_council_tax_file <- function(file_path, district_name, conn) {
  # Read the CSV data
  council_tax_data <- read.csv(file_path)

  # Clean up the column names to remove unnecessary symbols
  colnames(council_tax_data) <- c("name", "band_a", "band_b", "band_c", "band_d", "band_e", "band_f", "band_g", "band_h")

  # Convert the band columns from text to numeric values
  council_tax_data[, 2:9] <- lapply(council_tax_data[, 2:9], function(x) as.numeric(gsub(",", "", x)))

  # Get local authority id for the given district name
  authority_query <- sprintf("SELECT id FROM districts WHERE name = '%s'", district_name)
  district_id <- dbGetQuery(conn, authority_query)$id

  if (length(district_id) == 0) {
    stop(paste("No local authority found for district:", district_name))
  }

  # Loop through each row and insert into parish and council_tax_rates tables
  for (i in 1:nrow(council_tax_data)) {
    parish_name <- council_tax_data$name[i]

    # Check if the parish already exists in the 'parish' table
    parish_query <- sprintf("SELECT id FROM parish WHERE name = '%s' AND district_id = %d", parish_name, district_id)
    parish_id <- dbGetQuery(conn, parish_query)$id

    if (length(parish_id) == 0) {
      # Insert new parish into the 'parish' table
      dbExecute(conn, sprintf("INSERT INTO parish (name, district_id) VALUES ('%s', %d)", parish_name, district_id))
      parish_id <- dbGetQuery(conn, parish_query)$id
    }

    # Insert council tax data into the 'council_tax_rates' table
    dbExecute(conn, sprintf("
      INSERT INTO council_tax_rates (parish_id, band_a, band_b, band_c, band_d, band_e, band_f, band_g, band_h)
      VALUES (%d, %f, %f, %f, %f, %f, %f, %f, %f)",
                            parish_id,
                            council_tax_data$band_a[i],
                            council_tax_data$band_b[i],
                            council_tax_data$band_c[i],
                            council_tax_data$band_d[i],
                            council_tax_data$band_e[i],
                            council_tax_data$band_f[i],
                            council_tax_data$band_g[i],
                            council_tax_data$band_h[i]
    ))
  }
}

# Define the list of files and their corresponding district names.
# Data Sources:
# - cherwell_council_tax.csv, SouthOxfordshireCouncilTax.csv, ValeOfWhiteHorseCouncilTax.csv:
#   These files were generated using specific Python scripts, which scrape or fetch data
#   from the respective district's government websites (Cherwell, South Oxfordshire, and
#   Vale of White Horse).
# - westoxon_council_tax.csv: Created using an R script that processes the West Oxfordshire
#   council tax data, extracted from relevant sources or government datasets.
# - oxford_city_council_tax.csv: This file is part of the original dataset available from the
#   government or a direct data download from the Oxford City Council's official resources.
files_and_districts <- list(
  list(file = "./cherwell_council_tax.csv", district = "Cherwell"),
  list(file = "./westoxon_council_tax.csv", district = "West Oxfordshire"),
  list(file = "./southoxon_council_tax.csv", district = "South Oxfordshire"),
  list(file = "./oxford_city_council_tax.csv", district = "Oxford"),
  list(file = "./vale_of_white_horse_council_tax.csv", district = "Vale of White Horse")
)

# Go through each file and process it
for (file_info in files_and_districts) {
  process_council_tax_file(file_info$file, file_info$district, conn)
}

# Check the inserted parish tax rates
parishes <- dbGetQuery(conn, "SELECT * FROM parishes")
print(parishes)

# Check the inserted council tax rates
council_tax_rates <- dbGetQuery(conn, "SELECT * FROM council_tax_rates")
print(council_tax_rates)

