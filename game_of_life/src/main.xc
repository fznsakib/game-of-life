// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <stdio.h>
#include <print.h>
#include <xs1.h>
#include "pgmIO.h"
#include "i2c.h"

#define  ALIVECELL 255      // alive cell byte
#define  MAX_ROUNDS 100     // maximum rounds to be executed

typedef unsigned char uchar;    // using uchar as shorthand

#define  IMHT 64    // image height
#define  IMWD 64    // image width

char infname[] = "64x64.pgm";       // input image path
char outfname[] = "testout.pgm";    // output image path

// deciding type of int to use depending on image size
#if (IMWD >= 32)
    #define b_int uint32_t
    #define INTSIZE 32
#elif (IMWD >= 16)
    #define b_int uint16_t
    #define INTSIZE 16
#endif

// change number of workers depending on image size of input
#if (IMWD > 512)
    #define WORKERNO 4
#elif (IMWD >= 16)
    #define WORKERNO 8
#endif

// change distributor tile depending on how many workers
#if (WORKERNO == 4 || WORKERNO == 2)
    #define DISTRIBUTOR_TILE 0
#elif (WORKERNO != 4)
    #define DISTRIBUTOR_TILE 1
#endif

#define  WORKERHT ((IMHT / WORKERNO) + 2)  // height of worker boards depending on number of workers
#define  WORKERWD (IMWD / INTSIZE)         // width of worker boards depending on number of workers

on tile[0] : in port buttons = XS1_PORT_4E;     // port to access xCore-200 buttons
on tile[0] : out port leds = XS1_PORT_4F;       // port to access xCore-200 LEDs

// interface ports to orientation
on tile[0] : port p_scl = XS1_PORT_1E;
on tile[0] : port p_sda = XS1_PORT_1F;

#define FXOS8700EQ_I2C_ADDR 0x1E            // register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel cOut
//
/////////////////////////////////////////////////////////////////////////////////////////

void DataInStream(char infname[], chanend cOut) {

  while(1) {

      int res;
      uchar line[ IMWD ];
      printf( "DataInStream: Start...\n" );

      // open PGM file
      res = _openinpgm( infname, IMWD, IMHT );
      if( res ) {
        printf( "DataInStream: Error opening %s\n.", infname );
        return;
      }

      // read image line-by-line and send byte by byte to channel cOut
      for( int y = 0; y < IMHT; y++ ) {

        _readinline( line, IMWD );
        for( int x = 0; x < IMWD; x++ ) {
          cOut <: line[x];
        }

      }

      // close PGM image file
      _closeinpgm();
      printf( "DataInStream: Done...\n" );
      return;

  }

}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Write pixel stream from channel cIn to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////

void DataOutStream(char outfname[], chanend cIn, chanend toVisualiser) {

  while(1) {

      b_int val = 0;
      int res;
      uchar line[ IMWD ];
      cIn :> val;

      // open PGM file
      printf( "DataOutStream: Start...\n" );
      res = _openoutpgm( outfname, IMWD, IMHT );
      if( res ) {
        printf( "DataOutStream: Error opening %s\n.", outfname );
        return;
      }

      // send 1 to export to turn on blue LED
      toVisualiser <: 1;

      // compile each line of the image and write the image line-by-line
      for( int y = 0; y < IMHT; y++ ) {

        for( int x = 0; x < IMWD; x++ ) {
          cIn :> line[ x ];
        }
        _writeoutline( line, IMWD );

      }

      // send 0 back to export to turn off blue LED
       toVisualiser <: 0;

      // close the PGM image
      _closeoutpgm();
      printf( "DataOutStream: Done...\n" );

      printf("------- Export COMPLETE -------\n");

  }

}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Functions for listening to xMOS interface
//
/////////////////////////////////////////////////////////////////////////////////////////

// LISTENS for button presses on the board
void buttonListener(in port b, chanend cButton1, chanend cButton2) {

  int r;

  while (1) {

      b when pinseq(15)  :> r;    // check that no button is pressed
      b when pinsneq(15) :> r;    // check if some buttons are pressed

      if (r == 14) {               // if button 1 is pressed
          cButton1 <: r;
          break;
      }

  }

  while (1) {

    b when pinseq(15)  :> r;    // check that no button is pressed
    b when pinsneq(15) :> r;    // check if some buttons are pressed

    if (r == 13) {               // if button 2 is pressed
          cButton2 <: r;
          cButton2 :> r;
    }

  }

}

// DISPLAYS an LED pattern
int showLEDs(out port p, chanend fromVisualiser) {

  int pattern; // 1st bit: separate green LED
               // 2nd bit: blue LED
               // 3rd bit: green LED
               // 4th bit: red LED

  while (1) {
    fromVisualiser :> pattern;   // receive new pattern from visualiser
    p <: pattern;                // send pattern to LED port
  }

  return 0;

}

void visualiser(chanend toLEDs, chanend fromDistributorRounds, chanend fromDistributorPaused, chanend fromDataOut) {

  int pattern = 0;
  int round = 0;        // alternate between green and flashing green
  int exporting = 0;
  int paused = 0;

  while (1) {

    select {

        case fromDistributorRounds :> round:    // update round
            break;
        case fromDistributorPaused :> paused:   // update pause state
            break;
        case fromDataOut :> exporting:          // update exporting variable
            break;

    }

    // ensure only one light on at any one time
    if (paused == 1) pattern = (round % 2) + 8;
    else if (exporting == 1) pattern = (round % 2) + 2;
    else pattern = (round % 2) + 4;
    toLEDs <: pattern;

  }

}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Initialise and  read orientation, send first tilt event to channel
//
/////////////////////////////////////////////////////////////////////////////////////////

void orientation( client interface i2c_master_if i2c, chanend toDist) {

  i2c_regop_res_t result;
  char status_data = 0;
  int paused = 0;

  // configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  // enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  // probe the orientation x-axis forever
  while (1) {

    // check until new orientation data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);

    // get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

    // send signal to distributor after first tilt
    if (x>50) {

      toDist <: x;
      toDist :> x;
      paused = 1;

      while (paused == 1) {
          x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);
          if ((x > -50) && (x < 50)) paused = 0;
      }

      toDist <: paused;

    }

  }

}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Functions to pack 32 bytes into 1 integer
//
/////////////////////////////////////////////////////////////////////////////////////////

b_int setBit(b_int intByte[IMHT][WORKERWD], int k, int y) {

    int i = k / INTSIZE;            // wanted index within the array of ints
    int position = k % INTSIZE;     // position of bit within int

    unsigned int bit = 1;           // 0000...001

    bit = bit << position;          // shift the bit by k positions for comparison

    intByte[y][i] = intByte[y][i] | bit;      // set the bit at the k-th position in A[i]

    return intByte[y][i];

}

b_int setWorkerBit(b_int intByte[WORKERHT][WORKERWD], int k, int y) {

    int i = k / INTSIZE;
    int position = k % INTSIZE;

    unsigned int bit = 1;

    bit = bit << position;

    intByte[y][i] = intByte[y][i] | bit;

    return intByte[y][i];

}

b_int clearBit(b_int intByte[IMHT][WORKERWD], int k, int y) {

    int i = k/32;
    int position = k%32;

    unsigned int bit = 1;

    bit = bit << position;
    bit = ~bit;                 // negate byte so that chosen bit is 0

    intByte[y][i] = intByte[y][i] & bit;    // reset the bit at the k-th position in intByte[y][i]

    return intByte[y][i];

}

b_int checkBit( b_int intByte[IMHT][WORKERWD],  int k, int y) {

      return ( (intByte[y][k / INTSIZE] & (1 << (k % INTSIZE) )) != 0 ) ;

}

b_int checkWorkerBit( b_int intByte[WORKERHT][WORKERWD],  int k, int y) {

      return ( (intByte[y][k / INTSIZE] & (1 << (k % INTSIZE) )) != 0 ) ;

}

b_int checkWorkerBitTEST( b_int intByte[WORKERNO][WORKERHT][WORKERWD],  int k, int y, int i) {

      return ( (intByte[i][y][k / INTSIZE] & (1 << (k % INTSIZE) )) != 0 ) ;

}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Timer function for monitoring processing time
//
/////////////////////////////////////////////////////////////////////////////////////////

void timerFunction(chanend toDistributor) {

    timer t;
    int timerOn = 0;
    float roundTime;
    float totalElapsedTime = 0;
    float period = 100000000;
    uint32_t startTime, endTime;

    while(1) {

        toDistributor :> timerOn;

        if (timerOn == 3) {
            toDistributor <: totalElapsedTime;
        }

        else {
            t :> startTime;
            toDistributor :> timerOn;
            t :> endTime;
            roundTime = (endTime - startTime)/period;
            toDistributor <: roundTime;
            totalElapsedTime = totalElapsedTime + roundTime;
        }

    }

}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Function for distributor to send out work to worker threads
//
/////////////////////////////////////////////////////////////////////////////////////////

void distributor(chanend cIn, chanend cOut, chanend cButton1, chanend cButton2, chanend cVisualiserRounds, chanend cVisualiserPaused, chanend cWorker[WORKERNO], chanend cTilt, chanend cTimer) {

  uchar charVal;
  b_int intVal = 0;
  int chanBuffer = 0;
  int paused = 0;
  int aliveCells = 0;
  float roundTime = 0;
  float totalTime = 0;

  b_int packedBoard[IMHT][WORKERWD];
  b_int workerBoard[WORKERNO][WORKERHT][WORKERWD];

  int round = 0;

  // starting up and wait for press of button 1 on the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Press Button 1 to begin...\n" );
  cButton1 :> int value;
  cVisualiserRounds <: 1;

  // initialise workerBoards
  for (int i = 0; i < WORKERNO ; i++) {
    for( int y = 0; y < WORKERHT; y++ ) {       // initialise workerBoards
      for( int x = 0; x < WORKERWD; x++ ) {     // go through each pixel per line
          workerBoard[i][y][x] = 0;
      }
    }
  }

  // initialise packed board
  for( int y = 0; y < IMHT; y++ ) {         // initialise workerBoard 1
    for( int x = 0; x < WORKERWD; x++ ) {   // go through each pixel per line
        packedBoard[y][x] = 0;
    }
  }

  // pack board from data in
  for (int y = 0; y < IMHT; y++) {
    for (int x = 0; x < IMWD; x++) {
        cIn :> charVal;
        if (charVal == ALIVECELL) {
            aliveCells++;
            setBit(packedBoard, x, y);
        }
    }
  }


  // begin looping rounds
  while(round < MAX_ROUNDS) {

      select {

          // wait for tilt to pause
          case cTilt :> chanBuffer:

              cTimer <: 3;
              cTimer :> totalTime;
              cVisualiserPaused <: 1;

              // check for total alive cells
              aliveCells = 0;
              for (int y = 0; y < IMHT; y++) {
                  for (int x = 0; x < IMWD; x++) {
                      intVal = checkBit(packedBoard, x, y);
                      if (intVal == 1) aliveCells++;
                  }
              }

              printf("-------------- PAUSED --------------\n\n");
              printf("STATUS REPORT: \n");
              printf("Number of rounds processsed: %d\n", round);
              printf("Number of alive cells in current configuration: %d\n", aliveCells);
              printf("Processing time elapsed since start of simulation: %fs\n\n", totalTime);

              paused = 1;

              // wait for board to go back to normal orientation
              cTilt <: chanBuffer;
              cTilt :> paused;
              cVisualiserPaused <: 0;
              printf("------------- RESUMING -------------\n\n\n");

              break;

          // wait for button 2 press to export
          case cButton2 :> chanBuffer:

              cOut <: intVal;
              printf("Begin exporting...\n");

              // output board to console if button 2 is pressed
              for (int y = 0; y < IMHT; y++) {
                  for (int x = 0; x < IMWD; x++) {

                      // convert from uint to uchar so that image can be exported
                      intVal = checkBit(packedBoard, x, y);
                      if (intVal == 1) charVal = 255;
                      else charVal = 0;
                      cOut <: charVal;

                  }
              }

              // return control to button listener
              cButton2 <: chanBuffer;

              break;

          ////////////////////////////////////////////////////////////////////////
          ////////////////////    Main distribution code    //////////////////////
          ////////////////////////////////////////////////////////////////////////

          default:

            // start timer
            cTimer <: 1;

            // initialise workerBoard insides
            for (int i = 0; i < WORKERNO; i++) {
                for (int y = 0; y < WORKERHT - 2; y++) {
                  for (int x = 0; x < WORKERWD; x++) {
                    workerBoard[i][y + 1][x] = packedBoard[y + (i * (IMHT/WORKERNO))][x];
                  }
                }
            }


            // initialise workerBoard top/bottom
            // go through each worker
            for (int h = 0; h < WORKERNO; h ++) {
                // i = 0 for top, i = 1 for bottom
                for (int i = 0; i < 2; i ++) {
                    for (int x = 0; x < WORKERWD; x++) {

                        // exception for top of first workerboard as it loops around to the end of the whole board
                        if (i == 0) {
                            if (h == 0) workerBoard[h][0][x] = packedBoard[IMHT - 1][x];
                            else workerBoard[h][0][x] = packedBoard[((h*IMHT)/WORKERNO) - 1][x];
                        }

                        // cut into appropriate parts of the whole board to populate the rest of the workerboards
                        else {
                            if (h == (WORKERNO - 1)) workerBoard[h][WORKERHT - 1][x] = packedBoard[0][x];
                            else workerBoard[h][WORKERHT - 1][x] = packedBoard[((h+1)*IMHT)/WORKERNO][x];
                        }

                    }
                }
            }

            // initiate board in worker functions
            for (int i = 0; i < WORKERNO; i++) {
                for (int y = 0; y < WORKERHT; y++) {   // go through all lines
                    for (int x = 0; x < WORKERWD; x++) { // go through each pixel per line

                      cWorker[i] <: workerBoard[i][y][x];
                      cWorker[i] :> intVal;

                    }
                }
            }

            // receive new updated cells to populate final board
            for (int i = 0; i < WORKERNO; i++){
                for (int y = 0; y < WORKERHT; y++) {
                    for (int x = 0; x < IMWD; x++) {

                        // send permission to worker to update cell
                        cWorker[i] <: intVal;
                        // receive updated cell
                        cWorker[i] :> intVal;

                        // ignoring extra rows from worker board
                        if ((y != 0) && (y != (WORKERHT - 1))) {

                            // exception for first workerboard
                            if (i == 0) {
                                if (intVal == 1)
                                    setBit(packedBoard, x, (y - 1));
                                else
                                    clearBit(packedBoard, x, (y - 1));
                            }

                            else {
                                if (intVal == 1)
                                    setBit(packedBoard, x, y + (((i * IMHT)/WORKERNO)) - 1);
                                else
                                    clearBit(packedBoard, x, y + (((i * IMHT)/WORKERNO)) - 1);
                            }

                        }

                    }
                }
            }

            round++;
            cVisualiserRounds <: round;
            cTimer <: 1;
            cTimer :> roundTime;

            printf( "\nProcessing round %d completed. Elapsed round time: %fs\n", round, roundTime);

            // final export on round 100
            if (round == MAX_ROUNDS) {

                cTimer <: 3;
                cTimer :> totalTime;
                printf("TOTAL TIME: %fs\n",totalTime);
                printf("Begin exporting...\n");
                aliveCells = 0;
                cOut <: intVal;

                for (int y = 0; y < IMHT; y++) {
                    for (int x = 0; x < IMWD; x++) {

                        intVal = checkBit(packedBoard, x, y);
                        if (intVal == 1) {
                            charVal = 255;
                            aliveCells++;
                        }
                        else charVal = 0;
                        cOut <: charVal;

                    }
                }

                printf("FINAL STATUS REPORT: \n");
                printf("Number of rounds processsed: %d\n", round);
                printf("Number of alive cells in current configuration: %d\n", aliveCells);
                printf("Processing time elapsed since start of simulation: %fs\n\n", totalTime);
                cButton2 <: chanBuffer;

            }

            break;

            }

      }

  }


////////////////////////////////////////////////////////////////////////////////////////
//
// Functions to find neighbours and decide dead/alive
//
/////////////////////////////////////////////////////////////////////////////////////////

int countNeighbours(b_int board[WORKERHT][WORKERWD], int y, int x) {

    int neighbourCount = 0;

    // check all adjacent cells for living neighbours
    for (int i = -1; i < 2; i ++) {
        for (int j = -1; j < 2; j ++) {

            if (!((i == 0) && (j == 0))) {

                // mod by image width to check over the edge of the board
                if (checkWorkerBit(board, ((x + i + IMWD) % IMWD), y + j) == 1) {
                    neighbourCount++;
                }

            }

        }
    }

    return neighbourCount;

}

// apply rules of game of life on each cell, depending on their neighbour counts
int aliveOrDead(int neighbourCount, int currentCell) {

    if (currentCell == 1 && neighbourCount < 2) return 0;
    else if (currentCell == 1 && (neighbourCount == 2 || neighbourCount == 3)) return 1;
    else if (currentCell == 1 && neighbourCount > 3) return 0;
    else if ((currentCell == 0) && (neighbourCount == 3)) return 1;
    else return currentCell;

}


/////////////////////////////////////////////////////////////////////////////////////////
//
// Worker function being fed from distributor, each worker is working on a different
// part of the image
//
/////////////////////////////////////////////////////////////////////////////////////////

void worker(int index, chanend cWorker) {

    int round = 0;
    b_int cellBuffer = 0;
    b_int currentCell = 0;
    b_int updatedCell = 0;
    unsigned int aliveNeighbours = 0;

    b_int board[WORKERHT][WORKERWD];
    b_int finalBoard[WORKERHT][WORKERWD];

    while (round < MAX_ROUNDS) {

        // initialise newBoard with 0s
        for (int y = 0; y < WORKERHT; y++) {
            for (int x = 0; x < WORKERWD; x++) {

                board[y][x] = 0;
                finalBoard[y][x] = 0;

            }
        }

        // populate input board
        for (int y = 0; y < WORKERHT; y++) {
            for (int x = 0; x < WORKERWD; x++) {

                cWorker :> currentCell;
                board[y][x] = currentCell;
                cWorker <: currentCell;

            }
        }

        for (int y = 0; y < WORKERHT; y++) {
            for (int x = 0; x < IMWD; x++) {

                if (y != 0 && y != (WORKERHT - 1)){

                    aliveNeighbours = countNeighbours(board, y, x);
                    currentCell = checkWorkerBit(board, x, y);
                    cellBuffer = aliveOrDead(aliveNeighbours, currentCell);

                    if (cellBuffer == 1){
                        setWorkerBit(finalBoard, x, y);
                    }

                }

            }
        }

        // use newBoard full of neighbourCounts to convert into updated cell status
        for (int y = 0; y < WORKERHT; y++) {
            for (int x = 0; x < IMWD; x++) {

                cWorker :> currentCell;
                updatedCell = checkWorkerBit(finalBoard, x, y);
                cWorker <: updatedCell;

            }
        }

        round++;

    }

}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////

int main(void) {

    i2c_master_if i2c[1];   // interface to orientation

    chan cInIO, cOutIO, cControl, cLEDs, cTimer, cWorker[WORKERNO], cButton[2], cVisualiser[3];     // channel declarations

    par {

        on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 10);                   // server thread providing orientation data
        on tile[0]: orientation(i2c[0],cControl);                           // client thread reading orientation data

        on tile[1]: DataInStream(infname, cInIO);                           // thread to read in a PGM image
        on tile[1]: DataOutStream(outfname, cOutIO, cVisualiser[2]);        // thread to write out a PGM image

        on tile[0]: buttonListener(buttons, cButton[0], cButton[1]);

        on tile[0]: showLEDs(leds, cLEDs);
        on tile[0]: visualiser(cLEDs, cVisualiser[0], cVisualiser[1], cVisualiser[2]);

        on tile[1]: timerFunction(cTimer);

        on tile[DISTRIBUTOR_TILE]: distributor(cInIO, cOutIO, cButton[0], cButton[1], cVisualiser[0], cVisualiser[1], cWorker, cControl, cTimer);  // thread to coordinate work on image

        par (int i = 0; i < WORKERNO; i++)    {
            on tile[i%2]: worker(i, cWorker[i]);
        }

     }

    return 0;

}
