# Load necessary libraries
library(readr)
library(RSQLite)
library(readxl)
library(DBI)

# Read Excel data
table_1a <- read_excel("./HPSSA.xls", sheet = "1a")

# Remove NA values
table_1a <- na.omit(table_1a)

# Check data structure
str(table_1a)

# Set the first row as column names
colnames(table_1a) <- table_1a[1, ]
table_1a <- table_1a[-1, ]

# Remove unnecessary columns (Local authority code and Ward code)
table_1a <- table_1a[ , -c(1, 3)]

# Select the 5 districts in Oxfordshire
districts <- c("Oxford", "Cherwell", "South Oxfordshire", "Vale of White Horse", "West Oxfordshire")
oxfordshire_data <- table_1a[table_1a$`Local authority name` %in% districts, ]

# Replace "Year ending " with an empty string in column names
colnames(oxfordshire_data) <- gsub("Year ending ", "", colnames(oxfordshire_data))

# Define a function to convert month and year to "YYYY-MM-DD" format
convert_to_date <- function(month_year) {
  # Split the column name into month and year
  parts <- strsplit(month_year, " ")[[1]]
  month <- parts[1]
  year <- parts[2]

  # Define the last day of each month abbreviation
  last_day <- switch(month,
                     "Mar" = "03-31",
                     "Jun" = "06-30",
                     "Sep" = "09-30",
                     "Dec" = "12-31",
                     NA) # Return NA if there is no match

  # Return the formatted date "YYYY-MM-DD"
  return(paste(year, last_day, sep = "-"))
}

# Get all column names that need conversion (starting from 3, as the first two are area and ward names)
date_columns <- colnames(oxfordshire_data)[3:ncol(oxfordshire_data)]

# Iterate over the column names and apply the date conversion function
new_date_columns <- sapply(date_columns, convert_to_date)

# Replace the original column names with the new ones
colnames(oxfordshire_data)[3:ncol(oxfordshire_data)] <- new_date_columns

# Check the updated column names
print(colnames(oxfordshire_data))

# Export the data to a CSV file
write.csv(oxfordshire_data, file = "./oxfordshire_data.csv", row.names = TRUE)

conn <- dbConnect(RSQLite::SQLite(), "./oxfordshire_data.db")

# This part creates the 'districts' table to store different authorities
dbExecute(conn, "
CREATE TABLE districts (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL UNIQUE
);
")

# This part sets up the 'wards' table where each ward will be linked to its local authority
dbExecute(conn, "
CREATE TABLE wards (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  district_id INTEGER,
  name TEXT NOT NULL,
  FOREIGN KEY (district_id) REFERENCES districts(id)
);
")

# Set up the 'house_prices' table to store the prices for each ward by date
dbExecute(conn, "
CREATE TABLE house_prices (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  ward_id INTEGER,
  date DATE,
  price NUMERIC,
  FOREIGN KEY (ward_id) REFERENCES wards(id)
);
")

# Get unique local authority names from oxfordshire_data
unique_districts <- unique(oxfordshire_data$'District name')

# Print them out just to see what we’re working with
print(unique_districts)

# Insert each unique local authority into the districts table
for (authority in unique_districts) {
  # Check if this authority is already in the table
  exists <- dbGetQuery(conn, paste("SELECT COUNT(*) FROM districts WHERE name = '", authority, "';"))

  if (exists[1, 1] == 0) {
    # If it's not there, go ahead and insert it
    dbExecute(conn, paste0("INSERT INTO districts (name) VALUES ('", authority, "');"))
  }
}

# Query the districts table to make sure everything was inserted
districts <- dbGetQuery(conn, "SELECT * FROM districts;")

# Print out the local authorities
print(districts)

# Now we want to match up each ward with its corresponding local authority
ward_names <- oxfordshire_data$'Ward name'
district_names <- oxfordshire_data$'Local authority name'

# Use the local authority name to find the corresponding district_id
district_ids <- districts$id[match(district_names, districts$name)]

# Create a new data frame that combines district_id with ward names
ward_data <- data.frame(district_id = district_ids, name = ward_names)

# Insert the ward data into the 'wards' table in the database
dbWriteTable(conn, "wards", ward_data, append = TRUE, row.names = FALSE)

# Query the 'wards' table to check the data
wards_data <- dbGetQuery(conn, "SELECT * FROM wards")

# Print out the wards data to verify
print(wards_data)

# Disconnect from the database for now
dbDisconnect(conn)

# Reconnect to the database
conn <- dbConnect(RSQLite::SQLite(), "./oxfordshire_data.db")

# Get the number of rows in the oxfordshire_data dataframe
num_rows <- nrow(oxfordshire_data)
print(num_rows)

# Loop through each row in oxfordshire_data and insert price data into 'house_prices'
for (i in 1:num_rows) {
  ward_name <- oxfordshire_data$'Ward name'[i]

  # Escape any single quotes in the ward name (for SQL compatibility)
  ward_name <- gsub("'", "''", ward_name)

  # Find the ward_id by matching the ward name
  ward_id_query <- sprintf("SELECT id FROM wards WHERE name = '%s'", ward_name)
  ward_id <- dbGetQuery(conn, ward_id_query)$id

  # Loop through each date and price (from the 3rd column onward) and insert them
  for (j in 3:ncol(oxfordshire_data)) {
    date <- colnames(oxfordshire_data)[j]
    price <- as.numeric(oxfordshire_data[i, j])

    if (!is.na(price)) {  # Only insert data if the price is not NA
      # Insert the date and price for this ward
      insert_query <- sprintf("INSERT INTO house_prices (ward_id, date, price) VALUES (%d, '%s', %f)",
                              ward_id, date, price)
      dbExecute(conn, insert_query)
    }
  }
}

# Query the 'house_prices' table to confirm everything was inserted correctly
house_prices <- dbGetQuery(conn, "SELECT * FROM house_prices")
print(house_prices)


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


# Create and connect to SQLite database
conn <- dbConnect(RSQLite::SQLite(), "./oxfordshire_data.db")

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

# List of files and their respective district names
files_and_districts <- list(
  list(file = "./CherwellCouncilTax.csv", district = "Cherwell"),
  list(file = "./WestoxonCouncilTax.csv", district = "West Oxfordshire"),
  list(file = "./SouthoxonCouncilTax.csv", district = "South Oxfordshire"),
  list(file = "./OxfordCityCouncilTax.csv", district = "Oxford"),
  list(file = "./ValeofWhiteHorseCouncilTax.csv", district = "Vale of White Horse")
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

# Function to calculate the average house price for a given ward in a specific district over two years
calculate_average_price <- function(conn, district_name, ward_name, year1, year2) {
  # SQL query to fetch the house prices for the given ward and years
  query <- sprintf("
    SELECT AVG(price) as average_price
    FROM house_prices
    JOIN wards ON wards.id = house_prices.ward_id
    JOIN districts ON districts.id = wards.district_id
    WHERE districts.name = '%s'
      AND wards.name = '%s'
      AND strftime('%%Y', date) IN ('%s', '%s')
  ", district_name, ward_name, year1, year2)

  # Execute the SQL query
  result <- dbGetQuery(conn, query)
  print(result)
}

# Calculate the average price for a specific ward in a particular district over two years
calculate_average_price(conn, 'Oxford', 'Cowley', '2021', '2022')




# Average price calculation for a given ward in a particular district
calculate_avg_price <- function(conn, ward_name, district_name, year1, year2) {
  query <- sprintf("
    SELECT AVG(price) as avg_price
    FROM house_prices
    JOIN wards ON wards.id = house_prices.ward_id
    JOIN districts ON districts.id = wards.district_id
    WHERE districts.name = '%s'
    AND wards.name = '%s'
    AND (strftime('%%Y', date) = '%s' OR strftime('%%Y', date) = '%s')
  ", district_name, ward_name, year1, year2)

  result <- dbGetQuery(conn, query)
  return(result$avg_price)
}

# Example usage:
calculate_avg_price(conn, 'Summertown', 'Oxford', '2021', '2022')

# Find ward with the highest house price in a specific quarter
find_highest_price_ward <- function(conn, district_name, quarter_year) {
  query <- sprintf("
    SELECT wards.name as ward_name, MAX(price) as max_price
    FROM house_prices
    JOIN wards ON wards.id = house_prices.ward_id
    JOIN districts ON districts.id = wards.district_id
    WHERE districts.name = '%s'
    AND strftime('%%Y-%%m', date) = '%s'
  ", district_name, quarter_year)

  result <- dbGetQuery(conn, query)
  return(result)
}

# Example usage:
find_highest_price_ward(conn, 'Oxford', '2021-03')


# Define the function to find the difference in council tax charges for a specific band between two towns in the same district
find_council_tax_difference <- function(conn, district_name, town1, town2, band) {
  # Build the SQL query
  query <- sprintf("
    SELECT parish1.name AS town1, parish2.name AS town2,
           council_tax1.%s - council_tax2.%s AS difference
    FROM parishes AS parish1
    JOIN council_tax_rates AS council_tax1 ON parish1.id = council_tax1.parish_id
    JOIN parishes AS parish2 ON parish2.id = council_tax2.parish_id
    JOIN council_tax_rates AS council_tax2 ON parish2.id = council_tax2.parish_id
    JOIN districts ON districts.id = parish1.district_id
    WHERE districts.name = '%s'
      AND parish1.name = '%s'
      AND parish2.name = '%s'
  ", band, band, district_name, town1, town2)

  # Execute the query and fetch the result
  result <- dbGetQuery(conn, query)
}

# Example usage:
# Replace the values below with the district name, two towns, and band you want to query
find_council_tax_difference(conn, 'Cherwell', 'Banbury', 'Bicester', 'band_b')


# Function to find the town(s) with the lowest council tax for a given band in a specific district
find_lowest_council_tax_town <- function(conn, district_name, band) {
  # Construct the SQL query to find the lowest council tax rate for the specified band in the given district
  query <- sprintf(
    "
    SELECT parishes.name as town_name, council_tax_rates.%s as tax_rate
    FROM council_tax_rates
    JOIN parishes ON parishes.id = council_tax_rates.parish_id
    JOIN districts ON districts.id = parishes.district_id
    WHERE districts.name = '%s'
    AND council_tax_rates.%s = (
      SELECT MIN(council_tax_rates.%s)
      FROM council_tax_rates
      JOIN parishes ON parishes.id = council_tax_rates.parish_id
      JOIN districts ON districts.id = parishes.district_id
      WHERE districts.name = '%s'
    )
    ", band, district_name, band, band, band, district_name
  )

  # Execute the query and fetch the result
  result <- dbGetQuery(conn, query)

  # Print the results
  print(result)
}

# Example usage:
find_lowest_council_tax_town(conn, 'Cherwell', 'band_b')
find_lowest_council_tax_town(conn, 'West Oxfordshire', 'band_c')
find_lowest_council_tax_town(conn, 'Vale of White Horse', 'band_h')

# Disconnect from the database
dbDisconnect(conn)