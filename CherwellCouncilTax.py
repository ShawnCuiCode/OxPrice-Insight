import requests
from bs4 import BeautifulSoup
import csv
import time
from urllib.parse import urljoin

# Define the URL of the list page
list_page_url = 'https://www.cherwell.gov.uk/directory/149/council-tax-charges-202425'

# Send a GET request to get the content of the list page
response = requests.get(list_page_url)
response.raise_for_status()  # Check if the request was successful

# Parse the HTML content
soup = BeautifulSoup(response.content, 'html.parser')

# Find the <ul> tag that contains all the links
ul = soup.find('ul', {'class': 'list list--rich list--group-col2'})

# Extract names and URLs
records = []
for li in ul.find_all('li', {'class': 'list__item'}):
    a_tag = li.find('a', {'class': 'list__link'})
    name = a_tag.text.strip()
    href = a_tag['href']
    url = urljoin('https://www.cherwell.gov.uk', href)
    records.append({'name': name, 'url': url})

# Define the list of field names (CSV column names)
fieldnames = ['name', 'Band A (6/9)', 'Band B (7/9)',
              'Band C (8/9)', 'Band D (9/9)', 'Band E (11/9)', 'Band F (13/9)',
              'Band G (15/9)', 'Band H (18/9)', 'Council']

# Open the CSV file for writing
with open('CherwellCouncilTax.csv', 'w', newline='', encoding='utf-8') as csvfile:
    writer = csv.DictWriter(csvfile, fieldnames=fieldnames)
    writer.writeheader()

    # Iterate over each record and visit the detail page
    for index, record in enumerate(records):
        detail_page_url = record['url']
        print(f"Processing {index + 1}/{len(records)}: {record['name']}")

        try:
            # Send a GET request to get the detail page content
            response = requests.get(detail_page_url)
            response.raise_for_status()

            # Parse the HTML content of the detail page
            detail_soup = BeautifulSoup(response.content, 'html.parser')

            # Find the <dl> definition list
            dl = detail_soup.find('dl', {'class': 'list list--definition'})
            if not dl:
                print(f"Definition list not found, skipping {record['name']}")
                continue

            # Extract key-value pairs
            dt_tags = dl.find_all('dt', {'class': 'list--definition__heading'})
            dd_tags = dl.find_all('dd', {'class': 'list--definition__content'})

            for dt, dd in zip(dt_tags, dd_tags):
                key = dt.text.strip()
                value = dd.text.strip()
                # Only keep the 'Band' fields
                if 'Band' in key:
                    record[key] = value

            # Add the 'Council' field
            record['Council'] = 1

            # Remove unwanted fields
            record.pop('url', None)
            record.pop('Location', None)
            record.pop('Information', None)

            # Write the record to the CSV file
            writer.writerow(record)

        except requests.exceptions.RequestException as e:
            print(f"Request failed: {e}")

        # Wait 1 second between requests to be polite to the server
        time.sleep(1)