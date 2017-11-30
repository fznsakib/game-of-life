// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include <print.h>
#include "i2c.h"

#define  IMHT 1024                  //image height
#define  IMWD 1024                  //image width
#define  ALIVECELL 255              //alive cell byte
#define  MAX_ROUNDS 100             //maximum rounds to be executed
#define  WORKERHT ((IMHT / 8) + 2)
#if (IMWD >= 32)
    #define b_int uint32_t
    #define INTSIZE 32
#elif (IMWD >= 16)
    #define b_int uint16_t
    #define INTSIZE 16
#endif

typedef unsigned char uchar;      //using uchar as shorthand

on tile[0] : port p_scl = XS1_PORT_1E;         //interface ports to orientation
on tile[0] : port p_sda = XS1_PORT_1F;

on tile[0] : in port buttons = XS1_PORT_4E; //port to access xCore-200 buttons
on tile[0] : out port leds = XS1_PORT_4F;   //port to access xCore-200 LEDs

#define FXOS8700EQ_I2C_ADDR 0x1E  //register addresses for orientation
#define FXOS8700EQ_XYZ_DATA_CFG_REG 0x0E
#define FXOS8700EQ_CTRL_REG_1 0x2A
#define FXOS8700EQ_DR_STATUS 0x0
#define FXOS8700EQ_OUT_X_MSB 0x1
#define FXOS8700EQ_OUT_X_LSB 0x2
#define FXOS8700EQ_OUT_Y_MSB 0x3
#define FXOS8700EQ_OUT_Y_LSB 0x4
#define FXOS8700EQ_OUT_Z_MSB 0x5
#define FXOS8700EQ_OUT_Z_LSB 0x6

char infname[] = "1024x1024.pgm";     //put your input image path here
char outfname[] = "testout.pgm";    //put your output image path here


/////////////////////////////////////////////////////////////////////////////////////////
//
// Read Image from PGM file from path infname[] to channel cOut
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataInStream(char infname[], chanend cOut)
{
  while(1){
  int res;
  uchar line[ IMWD ];

  printf( "DataInStream: Start...\n" );

  //Open PGM file
  res = _openinpgm( infname, IMWD, IMHT );
  if( res ) {
    printf( "DataInStream: Error opening %s\n.", infname );
    return;
  }

  //Read image line-by-line and send byte by byte to channel cOut
  for( int y = 0; y < IMHT; y++ ) {
    _readinline( line, IMWD );

    for( int x = 0; x < IMWD; x++ ) {
      cOut <: line[x];
      //printf( "-%4.1d ", line[ x ] ); //show image values
    }
    //printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream: Done...\n" );
  return;
  }
}



/////////////////////////////////////////////////////////////////////////////////////////
//
// Function to pack 32 bytes into 1 integer
//
/////////////////////////////////////////////////////////////////////////////////////////

b_int setBit(b_int intByte[IMHT][IMWD/INTSIZE], int k, int y){
    int i = k / INTSIZE;            //gives the corresponding index in the array A
    int pos = k % INTSIZE;          //gives the corresponding bit position in A[i]

    unsigned int flag = 1;   // flag = 0000.....00001

    flag = flag << pos;      // flag = 0000...010...000   (shifted k positions)

    intByte[y][i] = intByte[y][i] | flag;      // Set the bit at the k-th position in A[i]

    return intByte[y][i];
}

b_int setWorkerBit(b_int intByte[WORKERHT][IMWD/INTSIZE], int k, int y){
    int i = k / INTSIZE;            //gives the corresponding index in the array A
    int pos = k % INTSIZE;          //gives the corresponding bit position in A[i]

    unsigned int flag = 1;   // flag = 0000.....00001

    flag = flag << pos;      // flag = 0000...010...000   (shifted k positions)

    intByte[y][i] = intByte[y][i] | flag;      // Set the bit at the k-th position in A[i]

    return intByte[y][i];
}

b_int clearBit(b_int intByte[IMHT][IMWD/INTSIZE], int k, int y){
    int i = k/32;
    int pos = k%32;

    unsigned int flag = 1;  // flag = 0000.....00001

    flag = flag << pos;     // flag = 0000...010...000   (shifted k positions)
    flag = ~flag;           // flag = 1111...101..111

    intByte[y][i] = intByte[y][i] & flag;     // RESET the bit at the k-th position in A[i]

    return intByte[y][i];
}

b_int checkBit( b_int intByte[IMHT][IMWD/INTSIZE],  int k, int y){
      return ( (intByte[y][k / INTSIZE] & (1 << (k % INTSIZE) )) != 0 ) ;
}

b_int checkWorkerBit( b_int intByte[WORKERHT][IMWD/INTSIZE],  int k, int y){
      return ( (intByte[y][k / INTSIZE] & (1 << (k % INTSIZE) )) != 0 ) ;
}


/////////////////////////////////////////////////////////////////////////////////////////
//
//
// Function for listening to xMOS interface
//
//
/////////////////////////////////////////////////////////////////////////////////////////

//DISPLAYS an LED pattern
int showLEDs(out port p, chanend fromVisualiser) {
  int pattern; //1st bit...separate green LED
               //2nd bit...blue LED
               //3rd bit...green LED
               //4th bit...red LED
  while (1) {
    fromVisualiser :> pattern;   //receive new pattern from visualiser
    p <: pattern;                //send pattern to LED port
  }
  return 0;
}

void buttonListener(in port b, chanend cButton1, chanend cButton2) {
  int r;
  while (1) {
      b when pinseq(15)  :> r;    // check that no button is pressed
      b when pinsneq(15) :> r;    // check if some buttons are pressed

      if (r == 14){               // if button 1 is pressed
          cButton1 <: r;
          break;
      }
  }

  while (1) {
    b when pinseq(15)  :> r;    // check that no button is pressed
    b when pinsneq(15) :> r;    // check if some buttons are pressed

    if (r == 13){               // if button 2 is pressed
          cButton2 <: r;
          cButton2 :> r;
    }
  }
}

void visualiser(chanend toLEDs, chanend fromDistributorRounds, chanend fromDistributorPaused, chanend fromDataOut) {
  int pattern = 0;
  int round = 0;            //alternate between green and flashing green
  int exporting = 0;
  int paused = 0;

  while (1) {
    select{
        case fromDistributorRounds :> round:
            break;
        case fromDistributorPaused :> paused:
            break;
        case fromDataOut :> exporting:
            break;
    }
    if (paused == 1) pattern = (round % 2) + 8;
    else if (exporting == 1) pattern = (round % 2) + 2;
    else pattern = (round % 2) + 4;
    toLEDs <: pattern;
  }
}

void timerFunction(chanend toDistributor){
    timer t;
    int timerOn = 0;
    uint32_t startTime, endTime, initialValue;
    float roundTime;
    float totalElapsedTime = 0;
    float period = 100000000;

    while(1){
        select{
            case t when timerafter(100000000) :> void:
                if (startTime < endTime){

                }
                break;
        }
        toDistributor :> timerOn;
        if (timerOn == 3){
            toDistributor <: totalElapsedTime;
        }
        else{
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
// Start your implementation by changing this function to implement the game of life
// by farming out parts of the image to worker threads who implement it...
// Currently the function just inverts the image
//
/////////////////////////////////////////////////////////////////////////////////////////

int flip(int n) {
    if (n==1) return 0;
    else return 1;
}


void distributor(chanend cIn, chanend cOut, chanend cButton1, chanend cButton2, chanend cVisualiserRounds, chanend cVisualiserPaused, chanend cWorker[8], chanend cTilt, chanend cTimer)
{
  uchar charVal;
  b_int intVal = 0;
  int chanBuffer = 0;
  int paused = 0;
  int aliveCells = 0;
  float roundTime = 0;
  float totalTime = 0;

  b_int packedBoard[IMHT][IMWD/INTSIZE];
  b_int workerBoard[8][WORKERHT][IMWD/INTSIZE];

  int round = 0;


  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Press Button 1 to begin...\n" );
  cButton1 :> int value;
  cVisualiserRounds <: 1;

  //initialise workerBoards
  for (int i = 0; i < 8 ; i++){
    for( int y = 0; y < WORKERHT; y++ ) {   //initialise workerBoards
      for( int x = 0; x < IMWD/INTSIZE; x++ ) { //go through each pixel per line
          workerBoard[i][y][x] = 0;
      }
    }
  }

  //initialise packed board
  for( int y = 0; y < IMHT; y++ ) {   //initialise workerBoard 1
    for( int x = 0; x < IMWD/INTSIZE; x++ ) { //go through each pixel per line
        packedBoard[y][x] = 0;
    }
  }

  //Pack board from data in
  for (int y = 0; y < IMHT; y++){
    for (int x = 0; x < IMWD; x++){
        cIn :> charVal;
        if (charVal == ALIVECELL){
            aliveCells++;
            setBit(packedBoard, x, y);
        }
    }
  }


  //BEGIN WHILE LOOP
  while(round < MAX_ROUNDS){
      select{
          //wait for tilt to pause
          case cTilt :> chanBuffer:
              cTimer <: 3;
              cTimer :> totalTime;
              cVisualiserPaused <: 1;

              //check for total alive cells
              aliveCells = 0;
              for (int y = 0; y < IMHT; y++){
                  for (int x = 0; x < IMWD; x++){
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

              //wait for board to go back to normal orientation
              cTilt <: chanBuffer;
              cTilt :> paused;
              cVisualiserPaused <: 0;
              printf("------------- RESUMING -------------\n\n\n");
              break;

          //wait for button 2 press to export
          case cButton2 :> chanBuffer:
              cOut <: intVal;
              printf("Begin exporting...\n");
              //output board to console if button 2 is pressed
              for (int y = 0; y < IMHT; y++){
                  for (int x = 0; x < IMWD; x++){
                      intVal = checkBit(packedBoard, x, y);
                      if (intVal == 1) charVal = 255;
                      else charVal = 0;
                      cOut <: charVal;
                  }
              }
              cButton2 <: chanBuffer;
              break;

          ////////////////////////////////////////////////////////////////////////
          ////////////////////    Main distribution code    //////////////////////
          ////////////////////////////////////////////////////////////////////////
          default:
            //Start timer
            cTimer <: 1;

            /*printf("INITIAL BOARD\n");
            for (int y = 0; y < IMHT; y++){
                for (int x = 0; x < IMWD; x++){
                    printf("%4.1d ", checkBit(packedBoard, x, y));
                }
            printf("\n");
            }*/


            //Initialise workerBoard insides
            for (int i = 0; i < 8; i++){
                for( int y = 0; y < WORKERHT - 2; y++ ) {   //initialise workerBoard 1
                  for( int x = 0; x < IMWD/INTSIZE; x++ ) {     //go through each pixel per line
                    workerBoard[i][y + 1][x] = packedBoard[y + (i * (IMHT/8))][x];
                  }
                }
            }


            //Initialise workerBoard top/bottom
            for (int h = 0; h < 8; h ++){
                for (int i = 0; i < 2; i ++){
                    for (int x = 0; x < IMWD/INTSIZE; x++){
                        if (i == 0){
                            if (h == 0) workerBoard[h][0][x] = packedBoard[IMHT - 1][x];
                            else workerBoard[h][0][x] = packedBoard[((h*IMHT)/8) - 1][x];
                        }
                        else{
                            if (h == 7) workerBoard[h][WORKERHT - 1][x] = packedBoard[0][x];
                            else workerBoard[h][WORKERHT - 1][x] = packedBoard[((h+1)*IMHT)/8][x];
                        }
                    }
                }
            }


            /*//Testing workerBoards
            printf("ORIGINAL WORKERBOARD 1\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
              for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                  printf("%4.1d ", checkWorkerBit(workerBoard, x, y, 0));
              }
              printf("\n");
            }

            printf("ORIGINAL WORKERBOARD 2\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
                for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                    printf("%4.1d ", checkWorkerBit(workerBoard, x, y, 1));
                }
                printf("\n");
              }

            printf("ORIGINAL WORKERBOARD 3\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
                for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                    printf("%4.1d ", checkWorkerBit(workerBoard, x, y, 2));
                }
                printf("\n");
              }

            printf("ORIGINAL WORKERBOARD 4\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
                for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                    printf("%4.1d ", checkWorkerBit(workerBoard, x, y, 3));
                }
                printf("\n");
              }
            printf("ORIGINAL WORKERBOARD 5\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
              for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                  printf("%4.1d ", checkWorkerBit(workerBoard, x, y, 4));
              }
              printf("\n");
            }

            printf("ORIGINAL WORKERBOARD 6\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
                for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                    printf("%4.1d ", checkWorkerBit(workerBoard, x, y, 5));
                }
                printf("\n");
              }

            printf("ORIGINAL WORKERBOARD 7\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
                for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                    printf("%4.1d ", checkWorkerBit(workerBoard, x, y, 6));
                }
                printf("\n");
              }

            printf("ORIGINAL WORKERBOARD 8\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
                for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                    printf("%4.1d ", checkWorkerBit(workerBoard, x, y, 7));
                }
                printf("\n");
              }*/


            //Take val from worker then send to data out
            //printf( "Processing...\n" );


            // Initiate board in worker functions
            for (int i = 0; i < 8; i++){
                for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
                    for( int x = 0; x < IMWD/INTSIZE; x++ ) { //go through each pixel per line

                      cWorker[i] <: workerBoard[i][y][x];
                      cWorker[i] :> intVal;

                    }
                }
            }

            // send work to each worker
            for( int worker1y = 0; worker1y < WORKERHT; worker1y++ ) {   //go through all lines
                for( int worker1x = 0; worker1x < IMWD; worker1x++ ) {
                    cWorker[0] <: intVal;                      //send permission to worker to update cell
                    cWorker[0] :> intVal;                      //receive updated cell

                    //ignoring extra rows from worker board
                    if ((worker1y != 0 && worker1y != (WORKERHT-1))){
                        if (intVal == 1)
                            setBit(packedBoard, worker1x, (worker1y - 1));
                        else
                            clearBit(packedBoard, worker1x, (worker1y - 1));
                    }
                }
            }

            for( int worker2y = 0; worker2y < WORKERHT; worker2y++ ) {   //go through all lines
                for( int worker2x = 0; worker2x < IMWD; worker2x++ ) {
                    cWorker[1] <: intVal;                //send permission to worker to update cell
                    cWorker[1] :> intVal;                //receive updated cell

                    if ((worker2y != 0 && worker2y != (WORKERHT-1))){
                        if (intVal == 1)
                            setBit(packedBoard, worker2x, worker2y + ((IMHT/8) - 1));
                        else
                            clearBit(packedBoard, worker2x, (worker2y + ((IMHT/8) - 1)));
                    }
                }
            }

            for( int worker3y = 0; worker3y < WORKERHT; worker3y++ ) {   //go through all lines
                for( int worker3x = 0; worker3x < IMWD; worker3x++ ) {
                    cWorker[2] <: intVal;                //send permission to worker to update cell
                    cWorker[2] :> intVal;                //receive updated cell

                    if ((worker3y != 0 && worker3y != (WORKERHT-1))){
                        if (intVal == 1)
                            setBit(packedBoard, worker3x, worker3y + ((IMHT/4) - 1));
                        else
                            clearBit(packedBoard, worker3x, worker3y + ((IMHT/4) - 1));
                    }
                }
            }

            for( int worker4y = 0; worker4y < WORKERHT; worker4y++ ) {   //go through all lines
                for( int worker4x = 0; worker4x < IMWD; worker4x++ ) {
                    cWorker[3] <: intVal;                //send permission to worker to update cell
                    cWorker[3] :> intVal;                //receive updated cell

                    if ((worker4y != 0 && worker4y != (WORKERHT-1))){
                        if (intVal == 1)
                            setBit(packedBoard, worker4x, worker4y + ((3*(IMHT/8)) - 1));
                        else{

                            clearBit(packedBoard, worker4x, worker4y + ((3*(IMHT/8)) - 1));
                        }
                    }
                }
            }

            for( int worker5y = 0; worker5y < WORKERHT; worker5y++ ) {   //go through all lines
                for( int worker5x = 0; worker5x < IMWD; worker5x++ ) {
                    cWorker[4] <: intVal;                //send permission to worker to update cell
                    cWorker[4] :> intVal;                //receive updated cell

                    if ((worker5y != 0 && worker5y != (WORKERHT-1))){
                        if (intVal == 1)
                            setBit(packedBoard, worker5x, worker5y + ((IMHT/2) - 1));
                        else
                            clearBit(packedBoard, worker5x, worker5y + ((IMHT/2) - 1));
                    }
                }
            }

            for( int worker6y = 0; worker6y < WORKERHT; worker6y++ ) {   //go through all lines
                for( int worker6x = 0; worker6x < IMWD; worker6x++ ) {
                    cWorker[5] <: intVal;                //send permission to worker to update cell
                    cWorker[5] :> intVal;                //receive updated cell

                    if ((worker6y != 0 && worker6y != (WORKERHT-1))){
                        if (intVal == 1)
                            setBit(packedBoard, worker6x, worker6y + ((5*(IMHT/8)) - 1));
                        else
                            clearBit(packedBoard, worker6x, worker6y + ((5*(IMHT/8)) - 1));
                    }
                }
            }


            for( int worker7y = 0; worker7y < WORKERHT; worker7y++ ) {   //go through all lines
                for( int worker7x = 0; worker7x < IMWD; worker7x++ ) {
                    cWorker[6] <: intVal;                //send permission to worker to update cell
                    cWorker[6] :> intVal;                //receive updated cell

                    if ((worker7y != 0 && worker7y != (WORKERHT-1))){
                        if (intVal == 1)
                            setBit(packedBoard, worker7x, worker7y + ((3*(IMHT/4)) - 1));
                        else
                            clearBit(packedBoard, worker7x, worker7y + ((3*(IMHT/4)) - 1));
                    }
                }
            }


            for( int worker8y = 0; worker8y < WORKERHT; worker8y++ ) {   //go through all lines
                for( int worker8x = 0; worker8x < IMWD; worker8x++ ) {
                    cWorker[7] <: intVal;                //send permission to worker to update cell
                    cWorker[7] :> intVal;                //receive updated cell

                    if ((worker8y != 0 && worker8y != (WORKERHT-1))){
                        if (intVal == 1)
                            setBit(packedBoard, worker8x, worker8y + ((7*(IMHT/8)) - 1));
                        else{

                            clearBit(packedBoard, worker8x, worker8y + ((7*(IMHT/8)) - 1));
                        }
                    }
                }
            }

            round++;
            cVisualiserRounds <: round;
            cTimer <: 1;
            cTimer :> roundTime;

            /*printf("FINAL BOARD NO: %d\n", round);
            for (int y = 0; y < IMHT; y++){
                  for (int x = 0; x < IMWD; x++){
                      printf("%4.1d ", checkBit(packedBoard, x, y));
                  }
                  printf("\n");
            }*/


            printf( "\nProcessing round %d completed. Elapsed round time: %fs\n", round, roundTime);

            //final export on round 100
            if (round == MAX_ROUNDS){
                printf("Begin exporting...\n");
                aliveCells = 0;
                cOut <: intVal;
                for (int y = 0; y < IMHT; y++){
                    for (int x = 0; x < IMWD; x++){
                        intVal = checkBit(packedBoard, x, y);
                        if (intVal == 1) {
                            charVal = 255;
                            aliveCells++;
                        }
                        else charVal = 0;
                        cOut <: charVal;
                    }
                }
                cTimer <: 3;
                cTimer :> totalTime;
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

int countNeighbours(b_int board[WORKERHT][IMWD/INTSIZE], int y, int x){
    int neighbourCount = 0;

    for (int i = -1; i < 2; i ++){
        for (int j = -1; j < 2; j ++){
            if (!((i == 0) && (j == 0))){
                if (checkWorkerBit(board, ((x + i + IMWD) % IMWD), y + j) == 1){
                    neighbourCount++;
                }
            }
        }
    }
    return neighbourCount;
}

// Apply rules of game of life on each cell, depending on their neighbour counts
int aliveOrDead(int neighbourCount, int currentCell){
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

void worker(int index, chanend cWorker){
    int round = 0;
    b_int cellBuffer = 0;
    b_int currentCell = 0;
    b_int updatedCell = 0;
    unsigned int aliveNeighbours = 0;
    b_int board[WORKERHT][IMWD/INTSIZE];
    b_int finalBoard[WORKERHT][IMWD/INTSIZE];

    while (round < MAX_ROUNDS){

        //initialise newBoard with 0s
        for (int y = 0; y < WORKERHT; y++){
            for (int x = 0; x < IMWD/INTSIZE; x++){
                board[y][x] = 0;
                finalBoard[y][x] = 0;
            }
        }

        //populate input board
        for (int y = 0; y < WORKERHT; y++){
            for (int x = 0; x < IMWD/INTSIZE; x++){
                cWorker :> currentCell;
                board[y][x] = currentCell;
                cWorker <: currentCell;
            }
        }

        /*if (index == 1){
            printf("WORKER BOARD 2 IN WORKER\n");
            for (int y = 0; y < WORKERHT; y++){
                for (int x = 0; x < IMWD; x++){
                    printf("%4.1d ", checkWorkerBit(board, x, y));
                }
                printf("\n");
            }
        }*/


        for (int y = 0; y < WORKERHT; y++){
            for (int x = 0; x < IMWD; x++){
                if (y != 0 && y != (WORKERHT - 1)){
                    aliveNeighbours = countNeighbours(board, y, x);
                    currentCell = checkWorkerBit(board, x, y);
                    cellBuffer = aliveOrDead(aliveNeighbours, currentCell);
                    if (cellBuffer == 1){
                        setWorkerBit(finalBoard, x, y);
                    }
                    //neighbourBoard[y][x] = aliveNeighbours;     //newBoard contains number of alive neighbours for each cell
                }
            }
        }


        //Neighbour count print
        /*if (index == 4){
            printf("NEIGHBOUR COUNT\n");
            for (int y = 0; y < WORKERHT; y++){
                for (int x = 0; x < IMWD; x++){
                    printf("%4.1d", neighbourBoard[y][x]);
                }
                printf("\n");
            }
        }*/


        //use newBoard full of neighbourCounts to convert into updated cell status
        for (int y = 0; y < WORKERHT; y++){
            for (int x = 0; x < IMWD; x++){
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
// Write pixel stream from channel cIn to PGM image file
//
/////////////////////////////////////////////////////////////////////////////////////////
void DataOutStream(char outfname[], chanend cIn, chanend toVisualiser)
{
  while(1){
      b_int val = 0;
      int res;
      uchar line[ IMWD ];

      cIn :> val;


      //Open PGM file
      printf( "DataOutStream: Start...\n" );
      res = _openoutpgm( outfname, IMWD, IMHT );
      if( res ) {
        printf( "DataOutStream: Error opening %s\n.", outfname );
        return;
      }

      // send 1 to export to turn on blue LED
      toVisualiser <: 1;

      //Compile each line of the image and write the image line-by-line
      for( int y = 0; y < IMHT; y++ ) {
        for( int x = 0; x < IMWD; x++ ) {
          cIn :> line[ x ];

          //printf( "-%4.1d ", line[ x ] );
        }
        _writeoutline( line, IMWD );
        //printf( "DataOutStream: Line written...\n" );
      }

      // send 0 back to export to turn off blue LED
       toVisualiser <: 0;

      //Close the PGM image
      _closeoutpgm();
      printf( "DataOutStream: Done...\n" );

      printf("------- Export COMPLETE -------\n");
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
  //int tilted = 0;
  int paused = 0;


  // Configure FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_XYZ_DATA_CFG_REG, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }
  
  // Enable FXOS8700EQ
  result = i2c.write_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_CTRL_REG_1, 0x01);
  if (result != I2C_REGOP_SUCCESS) {
    printf("I2C write reg failed\n");
  }

  //Probe the orientation x-axis forever
  while (1) {

    //check until new orientation data is available
    do {
      status_data = i2c.read_reg(FXOS8700EQ_I2C_ADDR, FXOS8700EQ_DR_STATUS, result);
    } while (!status_data & 0x08);

    //get new x-axis tilt value
    int x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);

    //send signal to distributor after first tilt
    if (x>50) {
      toDist <: x;
      toDist :> x;
      paused = 1;
      while (paused == 1){
          x = read_acceleration(i2c, FXOS8700EQ_OUT_X_MSB);
          if ((x > -50) && (x < 50)) paused = 0;
      }

      toDist <: paused;
    }
  }
}

/////////////////////////////////////////////////////////////////////////////////////////
//
// Orchestrate concurrent system and start up all threads
//
/////////////////////////////////////////////////////////////////////////////////////////

int main(void) {

i2c_master_if i2c[1];               //interface to orientation

chan cInIO, cOutIO, cControl, cLEDs, cTimer;    //extend your channel definitions here
chan cWorker[8], cButton[2], cVisualiser[3];

par {
    on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 10);  //server thread providing orientation data
    on tile[0]: orientation(i2c[0],cControl);        //client thread reading orientation data
    on tile[1]: DataInStream(infname, cInIO);          //thread to read in a PGM image
    on tile[1]: DataOutStream(outfname, cOutIO, cVisualiser[2]);       //thread to write out a PGM image
    on tile[0]: distributor(cInIO, cOutIO, cButton[0], cButton[1], cVisualiser[0], cVisualiser[1], cWorker, cControl, cTimer);  //thread to coordinate work on image
    on tile[1]: worker(0, cWorker[0]);
    on tile[1]: worker(1, cWorker[1]);
    on tile[1]: worker(2, cWorker[2]);
    on tile[1]: worker(3, cWorker[3]);
    on tile[1]: worker(4, cWorker[4]);
    on tile[0]: worker(5, cWorker[5]);
    on tile[0]: worker(6, cWorker[6]);
    on tile[0]: worker(7, cWorker[7]);
    on tile[0]: buttonListener(buttons, cButton[0], cButton[1]);
    on tile[0]: showLEDs(leds, cLEDs);
    on tile[0]: visualiser(cLEDs, cVisualiser[0], cVisualiser[1], cVisualiser[2]);
    on tile[1]: timerFunction(cTimer);
  }

  return 0;
}
