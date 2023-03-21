import pickle as pk


def format_key(k):
    """Strip repo from key."""
    if k.startswith('toolshed'):
        return k.split('/', 4)[-1]
    return k


FILE = '/home/cameron/Downloads/openai_thoughts.pickle'
OUTFILE = 'installation_errors.csv'

with open(FILE, 'rb') as p:
    data = pk.load(p)

data = {
    format_key(k): v
    for k, v in data.items()
}

table = []

for tool_id, result in data.items():
    for stderr, response in result.items():
        try:
            response_str = response.choices[0].message.content
            if response_str.lower().startswith('yes'):
                installation_error = 'yes'
            else:
                installation_error = 'no'
        except AttributeError:
            installation_error = '-'
        table.append((
            tool_id,
            f'''"{stderr.replace('"', "'")}"''',
            installation_error,
        ))

with open(OUTFILE, 'w') as f:
    f.write('tool_id,stderr,installation_error\n')
    for row in table:
        f.write(','.join(row) + '\n')
