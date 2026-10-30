#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include "nback.h"

#define CONTENT_MAX_SIZE 100
// How many random tries before giving up on a match position or a value.
// Without a limit some settings (n close to the size, or only 2 values) loop forever.
#define MAX_TRIES 1000

struct nback_type {
    int content[CONTENT_MAX_SIZE];
    int size;
};

// Function to fill in a match (value and corresponding nBackString elements).
// Returns 1 if a match was placed, 0 if no free position was found.
int fillInAMatch(int nBackString[], int size, int combinations, int nback);

// Function to fill in all empty elements into nBackString
void fillInAllEmpty(int nBackString[], int size, int combinations, int nback);

/**
 * Function to create N-back string
 * @param nBackString   Array to write the string to
 * @param size          length of the wanted array
 * @param combinations  number of combinations we want (e.g. 3: uses numbers 1-2-3 for the positions)
 * @param matchPercentage  percentage of matches we want to have
 * @param nback         number of how many positions we want between the matching positions (e.g. 3; 1-2-3-1 is a match)
 */
void createNBackString(int nBackString[], int size, int combinations, int matchPercentage, int nback);

Nback create(int size, int combinations, int matchPercentage, int nback){
    // Generate the array to save positions to
    Nback s = malloc(sizeof(struct nback_type));
    if(size > CONTENT_MAX_SIZE){
        size = CONTENT_MAX_SIZE;
    }
    s->size = size;
    createNBackString(s->content, size, combinations, matchPercentage, nback);
    return s;
}

int getIndexOf(Nback s, int i){
    return s->content[i];
}

void destroy(Nback s){
    free(s);
}


void createNBackString(int nBackString[], int size, int combinations, int matchPercentage, int nback){
    // Seed the random number generator once. Seeding on every call gave identical
    // sequences when two were created within the same second (visual + audio).
    static int seeded = 0;
    if(!seeded){
        srand((unsigned)time(NULL));
        seeded = 1;
    }

    // Initialize all elements in nBackString to 0
    for(int i = 0; i<size; i++){
        nBackString[i] = 0;
    }

    // Calculate number of matches needed based on matchPercentage
    int matches = (int) size * matchPercentage / 100;

    // Fill in the specified number of matches into the nBackString
    // Stop early if there is no room left for another match
    for(int i = 0; i<matches; i++){
        if(!fillInAMatch(nBackString, size, combinations, nback)){
            break;
        }
    }

    // Fill in the remaining empty elements in nBackString
    fillInAllEmpty(nBackString, size, combinations, nback);

}

// Function to fill in a match (value and corresponding nBackString elements)
int fillInAMatch(int nBackString[], int size, int combinations, int nback){
    // Generate a random value for the match
    int value = 1 + rand() % combinations;

    // Try to find a valid position, but give up after MAX_TRIES
    for(int tries = 0; tries < MAX_TRIES; tries++){
        // Generate a random position in the nBackString
        int possition = rand() % size;

        // Check if the current and n-back positions are within the bounds
        // and if both positions are currently empty
        if((possition+nback < size) && nBackString[possition]== 0 && nBackString[possition+nback] == 0){
            // Fill in the match value for both positions
            nBackString[possition] = value;
            nBackString[possition+nback] = value;
            return 1;
        }
    }
    return 0;
}

// Function to fill in all empty elements in nBackString
void fillInAllEmpty(int nBackString[], int size, int combinations, int nback){
    for(int i = 0; i< size; i++){
        // Check if the current element is empty
        if(nBackString[i] == 0){
            int test = 0;
            int foo, bar;
            int tries = 0;
            while(test == 0){
                // Generate a random value for the empty element
                int value = 1 + rand() % combinations;

                // Initialize foo and bar flags to 0
                foo = 0;
                bar = 0;

                // Check if the previous n-back element is different from
                // the current value
                if(i-nback >= 0){
                    if (nBackString[i-nback] != value){
                        foo = 1;
                    }
                }else{
                    foo = 1;
                }

                // Check if the next n-back element is different from the
                // current value
                if(i+nback < size){
                    if(nBackString[i+nback] != value){
                        bar = 1;
                    }
                }else{
                    bar = 1;
                }

                // If both foo and bar flags are 1, it means the value is different
                // from the previous and next n-back elements, so we can fill in the
                // current element
                if(foo == 1 && bar == 1){
                    test = 1;  // Set the test flag to exit the loop
                    nBackString[i] = value;  // Fill in the value in the current empty element
                }else if(++tries >= MAX_TRIES){
                    // With very few values both neighbours can block every value
                    // (e.g. 1 before and 2 after with only 2 values). Then only avoid
                    // repeating the previous n-back element.
                    if(i-nback >= 0 && nBackString[i-nback] == value){
                        value = value % combinations + 1;
                    }
                    nBackString[i] = value;
                    test = 1;
                }
            }
        }

    }
}
