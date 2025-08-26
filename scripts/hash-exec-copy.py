#!/usr/bin/env python3
"""
Executive Vote Hash Generator

This script fetches an executive vote document from the sky-ecosystem/executive-votes repository
for a given date and calculates its keccak hash.

Usage:
    ./hash-exec-copy.py <date> OR
    make exec-hash date=<date>

Where <date> is in the format YYYY-MM-DD
"""

import argparse
from datetime import datetime
import requests
import subprocess

# Constants
INPUT_DATE_FORMAT = "%Y-%m-%d"
REPO_URL = "/sky-ecosystem/executive-votes"
GITHUB_API_BASE = "https://api.github.com/repos"
GITHUB_RAW_BASE = "https://raw.githubusercontent.com"


def find_exec_file_by_date(year, formatted_date):
    """Find the executive vote file for a specific date in the given year directory.

    Args:
        year (str): The year to search in
        formatted_date (str): The date in YYYY-MM-DD format

    Returns:
        str: The filename of the matching executive vote file

    Raises:
        SystemExit: If no matching file is found or if the API request fails
    """
    api_url = f"{GITHUB_API_BASE}{REPO_URL}/contents/{year}"

    try:
        # Get list of files in the year directory
        response = requests.get(api_url)
        response.raise_for_status()
        files = response.json()

        # Find files that match the date pattern
        pattern = f'executive-vote-{formatted_date}'
        matching_files = [file.get('name') for file in files if file.get(
            'type') == 'file' and pattern in file.get('name')]

        if matching_files:
            return matching_files[0]  # Return the first matching file

        raise SystemExit(
            f"Error: No executive vote file found for date {formatted_date}")

    except requests.exceptions.RequestException as e:
        raise SystemExit(
            f"HTTP Request failed when listing directory contents: {e}")


def get_executive(exec_title, year):
    """Fetch the executive vote document and its metadata.

    Args:
        exec_title (str): The filename of the executive vote document
        year (str): The year directory containing the document

    Returns:
        tuple: (content, url, commit_hash) where:
            - content (str): The content of the executive vote document
            - url (str): The raw GitHub URL to the document
            - commit_hash (str): The commit hash of the document

    Raises:
        SystemExit: If the executive copy is not found or the response is malformed
        requests.exceptions.RequestException: If the HTTP request fails
    """
    # Get the latest commit for this file
    commits_url = f"{GITHUB_API_BASE}{REPO_URL}/commits"
    file_path = f"{year}/{exec_title}"

    response = requests.get(
        commits_url,
        params={
            'path': file_path,
            'per_page': '1'})
    response.raise_for_status()
    commits = response.json()

    if not commits:
        raise SystemExit(f"Error: Executive copy not found: {exec_title}")

    commit_hash = commits[0].get("sha", "")

    if not commit_hash:
        raise SystemExit(
            f"Error: Executive copy commit hash not found: {exec_title}")

    # Get the file content from the specific commit
    raw_url = f"{GITHUB_RAW_BASE}{REPO_URL}/{commit_hash}/{file_path}"
    content_response = requests.get(raw_url)
    content_response.raise_for_status()

    # Store the URL for output
    executive_url = content_response.url

    # Remove trailing newline for consistent hashing
    content = content_response.text
    if content and content[-1] == '\n':
        content = content[:-1]

    return content, executive_url, commit_hash


def get_content_hash(content):
    """Calculate the keccak hash of the content using the 'cast' command.

    Args:
        content (str): The content to hash

    Returns:
        str: The keccak hash of the content

    Raises:
        SystemExit: If the 'cast' command is not found or fails
    """
    try:
        # Run the 'cast keccak' command with the content
        keccak_result = subprocess.run(
            ['cast', 'keccak', '--', content],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            check=True
        )
        return keccak_result.stdout.strip()  # Strip any whitespace
    except FileNotFoundError:
        raise SystemExit(
            "Error: The 'cast' command is not found. Ensure it's installed and in the PATH.")
    except subprocess.CalledProcessError as e:
        raise SystemExit(f"Command failed with error: {e.stderr}")


def parse_arguments():
    """Parse command line arguments.

    Returns:
        datetime: The parsed date object
    """
    parser = argparse.ArgumentParser(
        description="Fetch an executive vote document and calculate its keccak hash")
    parser.add_argument(
        "date",
        help=f"Date to find executive copy for (format: {INPUT_DATE_FORMAT})"
    )

    args = parser.parse_args()
    date_string = args.date.replace("date=", "")

    try:
        return datetime.strptime(date_string, INPUT_DATE_FORMAT)
    except ValueError:
        raise SystemExit(
            f"Invalid date format. Please use {INPUT_DATE_FORMAT}.")


def main():
    """Main function to fetch and hash an executive vote document."""
    # Parse the date argument
    date = parse_arguments()

    # Extract year and format date
    year = date.strftime("%Y")
    formatted_date = date.strftime('%Y-%m-%d')

    try:
        # Find the executive file for the given date
        exec_title = find_exec_file_by_date(year, formatted_date)

        # Get the content and metadata
        executive_content, executive_url, commit_hash = get_executive(
            exec_title, year)

        # Calculate the hash
        exec_hash = get_content_hash(executive_content)

        # Output results
        print(f"Executive Votes repo commit: {commit_hash}")
        print(f"Raw GitHub URL: {executive_url}")
        print(f"Exec copy hash: {exec_hash}")

    except requests.exceptions.RequestException as e:
        raise SystemExit(f"HTTP Request failed: {e}")


# Execute the main function if this script is run directly
if __name__ == "__main__":
    main()
