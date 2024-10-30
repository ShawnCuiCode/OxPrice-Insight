import requests
from bs4 import BeautifulSoup
import csv
import time

# Define target year (2024/2025)
YEAR = '23'  # '23' corresponds to 2024/2025

# Define council tax bands and their corresponding fractions
bands = [
    {'code': 'A', 'fraction': '6/9'},
    {'code': 'B', 'fraction': '7/9'},
    {'code': 'C', 'fraction': '8/9'},
    {'code': 'D', 'fraction': '9/9'},
    {'code': 'E', 'fraction': '11/9'},
    {'code': 'F', 'fraction': '13/9'},
    {'code': 'G', 'fraction': '15/9'},
    {'code': 'H', 'fraction': '18/9'}
]

# Define column headers for the CSV file
fieldnames = ['name', 'Council', 'Band A (6/9)', 'Band B (7/9)',
              'Band C (8/9)', 'Band D (9/9)', 'Band E (11/9)',
              'Band F (13/9)', 'Band G (15/9)', 'Band H (18/9)']

# Create a session object
session = requests.Session()

# URL to get the list of parishes
form_url = 'https://data.southoxon.gov.uk/ccm/support/Main.jsp?MODULE=Calculator'

# Fetch the page containing parish list
response = session.get(form_url)
response.raise_for_status()

# Parse the page content
soup = BeautifulSoup(response.content, 'html.parser')

# Find the dropdown menu for selecting parishes
parish_select = soup.find('select', {'name': 'PARISH'})

# Extract parish codes and names
parish_options = parish_select.find_all('option')
parish_list = []
for option in parish_options:
    code = option['value']
    name = option.text.strip()
    parish_list.append({'code': code, 'name': name})

print(f"Found {len(parish_list)} parishes.")

# Open a CSV file to write the data
with open('southoxon_council_tax_2024_2025.csv', 'w', newline='', encoding='utf-8') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()

    # Loop through each parish
    for index, parish in enumerate(parish_list):
        parish_code = parish['code']
        parish_name = parish['name']
        print(f"Processing parish {index + 1}/{len(parish_list)}: {parish_name}")

        # Create a record with default council name
        record = {'name': parish_name, 'Council': 'South Oxfordshire District Council'}

        # Loop through each council tax band
        for band in bands:
            try:
                # Prepare the form data
                payload = {
                    'MODULE': 'Calculation',
                    'YEAR': YEAR,
                    'PARISH': parish_code,
                    'FACTOR': band['code'],
                    'Submit': 'Submit'
                }

                # Send a POST request to fetch the band charges
                result_response = session.post('https://data.southoxon.gov.uk/ccm/support/Main.jsp?MODULE=Calculation', data=payload)
                result_response.raise_for_status()

                # Parse the result page
                result_soup = BeautifulSoup(result_response.content, 'html.parser')

                # Locate the Total amount field
                total_label_div = result_soup.find('div', class_='celldiv', string='Total')
                if total_label_div:
                    amount_div = total_label_div.find_next_sibling('div', class_='celldiv')
                    total_amount = amount_div.text.strip()
                    # Clean up the amount by removing symbols and commas
                    total_amount = total_amount.replace('£', '').replace(',', '').strip()
                    # Add the amount to the record
                    field_name = f"Band {band['code']} ({band['fraction']})"
                    record[field_name] = total_amount
                else:
                    print(f"No Total information found, skipping Band {band['code']}")
            except Exception as e:
                print(f"Error processing Band {band['code']}: {e}")
                continue

            # Add a short delay between requests
            time.sleep(0.1)

        # Write the record to the CSV file
        writer.writerow(record)

print("Data successfully saved to southoxon_council_tax_2024_2025.csv.")