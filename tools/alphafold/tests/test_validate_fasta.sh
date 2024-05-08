#!/usr/bin/env bash

echo "Testing monomer validation..."
EXPECT_EXIT_CODE=0
python scripts/validate_fasta.py       \
    test-data/test1.fasta              \
    --min_length 1                     \
    --max_length 1000                  \
    > /tmp/test-validate-fasta-1.fasta \
    2> /tmp/test-validate-fasta-1.stderr

if [ $? -ne $EXPECT_EXIT_CODE ]; then
    echo "Failed test 1"
    exit 1
fi

echo "Testing multimer validation..."
EXPECT_EXIT_CODE=0
python scripts/validate_fasta.py       \
    test-data/multimer.fasta           \
    --min_length 1                     \
    --max_length 1000                  \
    --multimer                         \
    > /tmp/test-validate-fasta-2.fasta \
    2> /tmp/test-validate-fasta-2.stderr

if [ $? -ne $EXPECT_EXIT_CODE ]; then
    echo "Failed test 2"
    exit 1
fi

echo "Testing monomer validation with custom max length..."
EXPECT_EXIT_CODE=1
python scripts/validate_fasta.py       \
    test-data/test1.fasta              \
    --min_length 1                     \
    --max_length 10                    \
    > /tmp/test-validate-fasta-3.fasta \
    2> /tmp/test-validate-fasta-3.stderr

if [ $? -ne $EXPECT_EXIT_CODE ]; then
    echo "Failed test 3"
    exit 1
fi

echo "Testing multimer validation with custom max sequences..."
EXPECT_EXIT_CODE=1
python scripts/validate_fasta.py        \
    test-data/multimer-3n.fasta         \
    --min_length 1                      \
    --max_length 1000                   \
    --max-sequences 2                   \
    --multimer                          \
    > /tmp/test-validate-fasta-3.fasta  \
    2> /tmp/test-validate-fasta-3.stderr

if [ $? -ne $EXPECT_EXIT_CODE ]; then
    echo "Failed test 3"
    exit 1
fi

echo "Tests passed"
