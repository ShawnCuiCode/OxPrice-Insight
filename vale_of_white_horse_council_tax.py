import requests
from bs4 import BeautifulSoup
import csv
import time

# Define the target year (2024/2025)
YEAR = '23'  # '23' corresponds to the 2024/2025 period

# Define council tax bands and their fractions
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

# Define the column names for the CSV file
fieldnames = ['name', 'Council', 'Band A (6/9)', 'Band B (7/9)',
              'Band C (8/9)', 'Band D (9/9)', 'Band E (11/9)',
              'Band F (13/9)', 'Band G (15/9)', 'Band H (18/9)']

# Create a session object
session = requests.Session()

# URL of the council tax calculator form
form_url = 'https://data.whitehorsedc.gov.uk/java/support/Main.jsp?MODULE=Calculator'

# Fetch the page with the parish list
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

# Open a CSV file to save the data
with open('whitehorsedc_council_tax.csv', 'w', newline='', encoding='utf-8') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()

    # Loop through each parish
    for index, parish in enumerate(parish_list):
        parish_code = parish['code']
        parish_name = parish['name']
        print(f"Processing parish {index + 1}/{len(parish_list)}: {parish_name}")

        # Create a record with default council name
        record = {'name': parish_name, 'Council': 'Vale of White Horse District Council'}

        # Loop through each tax band
        for band in bands:
            try:
                # Prepare the form data for the POST request
                payload = {
                    'MODULE': 'Calculation',
                    'YEAR': YEAR,
                    'PARISH': parish_code,
                    'FACTOR': band['code'],
                    'Submit': 'Submit'
                }

                # Send a POST request to get the band charges
                result_response = session.post('https://data.whitehorsedc.gov.uk/java/support/Main.jsp?MODULE=Calculation', data=payload)
                result_response.raise_for_status()

                # Parse the result page
                result_soup = BeautifulSoup(result_response.content, 'html.parser')

                # Find the Total amount field
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
                print(f"Error processing parish {parish_name} for Band {band['code']}: {e}")
                continue

            # Add a short delay between requests to be polite
            time.sleep(0.1)

        # Write the record to the CSV file
        writer.writerow(record)

print("Data successfully saved to whitehorsedc_council_tax.csv.")