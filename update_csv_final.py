import csv

input_file = '/home/mark/Development/SII-github/tradeoff_results_corrected.csv'
output_file = '/home/mark/Development/SII-github/tradeoff_results_corrected.csv'

rows = []
with open(input_file, 'r') as f:
    reader = csv.reader(f)
    for row in reader:
        if row[0] == 'A4' and row[1] == 'Open-NL':
            row[2] = '0.53'
            row[3] = '0.5'
        if row[0] == 'A5' and row[1] == 'Open-NL':
            row[2] = '0.35'
            row[3] = '1.3'
        rows.append(row)

with open(output_file, 'w', newline='') as f:
    writer = csv.writer(f)
    writer.writerows(rows)
