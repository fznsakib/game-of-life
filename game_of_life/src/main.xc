// COMS20001 - Cellular Automaton Farm - Initial Code Skeleton
// (using the XMOS i2c accelerometer demo code)

#include <platform.h>
#include <xs1.h>
#include <stdio.h>
#include "pgmIO.h"
#include <print.h>
#include "i2c.h"

#define  IMHT 16                  //image height
#define  IMWD 16                  //image width
#define  ALIVECELL 255            //alive cell byte
#define  MAX_ROUNDS 100           //maximum rounds to be executed
#define  WORKERHT 6

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

char infname[] = "test.pgm";     //put your input image path here
char outfname[] = "testout.pgm"; //put your output image path here


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
      //printf("HERE: %d ", line[x]);
      cOut <: line[x];
      printf( "-%4.1d ", line[ x ] ); //show image values
    }
    printf( "\n" );
  }

  //Close PGM image file
  _closeinpgm();
  printf( "DataInStream: Done...\n" );
  return;
  }
}



/////////////////////////////////////////////////////////////////////////////////////////
//
// Function to pack 8 bytes into one 8-bit value and vice-versa
//
/////////////////////////////////////////////////////////////////////////////////////////

uint8_t bytePacker(uchar inputByte){
    int binaryRep = 0;
    //int shift = 7;

    for (int i = 0; i < 8; i++){
        i = 0;
    }
    return binaryRep;
}

uchar* alias byteUnpacker(int inputInt){
    uchar dataArray[IMWD];
    int shift = 7;
    for (int i = 0; i < 8; i++){
        dataArray[i] = inputInt & 1 << (shift - i);
    }
    return dataArray;
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

//void timerFunction(chanend toDistributor){
//    timer t;
//    int timerOn = 0;
//    uint32_t startTime, endTime, roundTime;
//    int totalElapsedTime = 0;
//    const unsigned int period = 100000000;
//
//    while(1){
//        select{
//            case toDistributor :> timerOn:
//                if (timerOn == 1) t :> startTime;
//                else if (timerOn == 0) {
//                    t :> endTime;
//                    roundTime = endTime - startTime;
//                    totalElapsedTime = totalElapsedTime + roundTime;
//                }
//                else if (timerOn == 2){
//                    toDistributor <: totalElapsedTime;
//                }
//                else if (timerOn == 3){
//                    toDistributor <: roundTime;
//                }
//                break;
//        }
//    }
//}

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


void distributor(chanend cIn, chanend cOut, chanend cButton1, chanend cButton2, chanend cVisualiserRounds, chanend cVisualiserPaused, chanend cWorker1, chanend cWorker2, chanend cWorker3, chanend cWorker4, chanend cTilt, chanend cTimer)
{
  uchar val = 0;
  int chanBuffer = 0;
  int paused = 0;
  int aliveCells = 0;
  float roundTime = 0;
  float totalTime = 0;

  uchar board[IMHT][IMWD];
  uchar workerBoard1[WORKERHT][IMWD];
  uchar workerBoard2[WORKERHT][IMWD];
  uchar workerBoard3[WORKERHT][IMWD];
  uchar workerBoard4[WORKERHT][IMWD];
  int round = 0;


  //Starting up and wait for tilting of the xCore-200 Explorer
  printf( "ProcessImage: Start, size = %dx%d\n", IMHT, IMWD );
  printf( "Press Button 1 to begin...\n" );
  cButton1 :> int value;
  cVisualiserRounds <: 1;

  //Read in val from data in and initialise board
  for( int y = 0; y < IMHT; y++ ) {   //go through all lines
      for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line

          cIn :> val;                    //read the pixel value
          board[y][x] = val;             //initialise board with values
          if (val == 255) aliveCells++;  //count number of alive cells for status report
      }
  }

  //initialise workerBoards
  for( int y = 0; y < WORKERHT; y++ ) {   //initialise workerBoard 1
      for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
          workerBoard1[y][x] = 0;
          workerBoard2[y][x] = 0;
          workerBoard3[y][x] = 0;
          workerBoard3[y][x] = 0;
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
              cOut <: val;
              printf("Begin exporting...\n");
              //output board to console if button 2 is pressed
              for (int y = 0; y < IMHT; y++){
                  for (int x = 0; x < IMWD; x++){
                      val = board[y][x];
                      cOut <: val;
                  }
              }
              cButton2 <: chanBuffer;
              break;

          //Main distribution code
          default:

            //Start timer
            cTimer <: 1;

            //Initialise workerBoard insides
            for( int y = 0; y < WORKERHT - 2; y++ ) {   //initialise workerBoard 1
              for( int x = 0; x < IMWD; x++ ) {     //go through each pixel per line
                workerBoard1[y + 1][x] = board[y][x];
                workerBoard2[y + 1][x] = board[(y + (IMHT / 4))][x];
                workerBoard3[y + 1][x] = board[(y + (IMHT / 2))][x];
                //int i = y + ((3*IMHT)/ 4) - 1;
                //printf("%d \n", i);
                workerBoard4[y + 1][x] = board[(y + ((3*IMHT) / 4))][x];
              }
            }

            //Initialise workerBoard top/bottom
            /*for( int y = 0; y < 2; y++ ) {   //initialise workerBoard 1
                for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                  workerBoard1[y * (WORKERHT - 1)][x] = board[((y/2) * (IMHT))][x];
                  workerBoard2[y * (WORKERHT - 1)][x] = board[(flip(y)) * ((IMHT/2) - 1)][x];
                }
            }*/

            //Initialise workerBoard top/bottom
            for (int i = 0; i < 2; i ++){
                for (int x = 0; x < IMWD; x++){
                    if (i == 0){
                        workerBoard1[0][x] = board[IMHT - 1][x];
                        workerBoard2[0][x] = board[(IMHT/4) - 1][x];
                        workerBoard3[0][x] = board[(IMHT/2) - 1][x];
                        workerBoard4[0][x] = board[((3*IMHT)/4) - 1][x];
                    }
                    else{
                        workerBoard1[WORKERHT - 1][x] = board[(IMHT/4)][x];
                        workerBoard2[WORKERHT - 1][x] = board[IMHT/2][x];
                        workerBoard3[WORKERHT - 1][x] = board[((3*IMHT)/4)][x];
                        workerBoard4[WORKERHT - 1][x] = board[0][x];
                    }
                }
            }


            /*//Testing workerBoards
            printf("ORIGINAL WORKERBOARD 1\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
              for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                  printf("%4.1d ", workerBoard1[y][x]);
              }
              printf("\n");
            }

            printf("ORIGINAL WORKERBOARD 2\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
                for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                    printf("%4.1d ", workerBoard2[y][x]);
                }
                printf("\n");
              }

            printf("ORIGINAL WORKERBOARD 3\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
                for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                    printf("%4.1d ", workerBoard3[y][x]);
                }
                printf("\n");
              }

            printf("ORIGINAL WORKERBOARD 4\n");
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
                for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                    printf("%4.1d ", workerBoard4[y][x]);
                }
                printf("\n");
              }*/

            //Take val from worker then send to data out
            printf( "Processing...\n" );


            // Initiate board in worker functions
            for( int y = 0; y < WORKERHT; y++ ) {   //go through all lines
                for( int x = 0; x < IMWD; x++ ) { //go through each pixel per line
                  cWorker1 <: workerBoard1[y][x];
                  cWorker1 :> val;

                  cWorker2 <: workerBoard2[y][x];
                  cWorker2 :> val;

                  cWorker3 <: workerBoard3[y][x];
                  cWorker3 :> val;

                  cWorker4 <: workerBoard4[y][x];
                  cWorker4 :> val;
                }
            }

            // send work to each worker
            for( int worker1y = 0; worker1y < WORKERHT; worker1y++ ) {   //go through all lines
                for( int worker1x = 0; worker1x < IMWD; worker1x++ ) {
                    cWorker1 <: val;                      //send permission to worker to update cell
                    cWorker1 :> val;                      //receive updated cell

                    //ignoring extra rows from worker board
                    if ((worker1y != 0 && worker1y != (WORKERHT-1))){
                        board[worker1y - 1][worker1x] = val;
                    }
                }
            }

            for( int worker2y = 0; worker2y < WORKERHT; worker2y++ ) {   //go through all lines
                for( int worker2x = 0; worker2x < IMWD; worker2x++ ) {
                    cWorker2 <: val;                //send permission to worker to update cell
                    cWorker2 :> val;                //receive updated cell

                    if ((worker2y != 0 && worker2y != (WORKERHT-1))){
                        //board[worker2y + (WORKERHT - 3)][worker2x] = val;
                        board[worker2y + ((IMHT/4) - 1)][worker2x] = val;

                    }
                }
            }

            for( int worker3y = 0; worker3y < WORKERHT; worker3y++ ) {   //go through all lines
                for( int worker3x = 0; worker3x < IMWD; worker3x++ ) {
                    cWorker3 <: val;                //send permission to worker to update cell
                    cWorker3 :> val;                //receive updated cell

                    if ((worker3y != 0 && worker3y != (WORKERHT-1))){
                        board[worker3y + ((IMHT/2) - 1)][worker3x] = val;

                    }
                }
            }

            for( int worker4y = 0; worker4y < WORKERHT; worker4y++ ) {   //go through all lines
                for( int worker4x = 0; worker4x < IMWD; worker4x++ ) {
                    cWorker4 <: val;                //send permission to worker to update cell
                    cWorker4 :> val;                //receive updated cell

                    if ((worker4y != 0 && worker4y != (WORKERHT-1))){
                        board[worker4y + ((3*(IMHT/4)) - 1)][worker4x] = val;

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
                      printf("%4.1d ", board[y][x]);
                  }
                  printf("\n");
            }*/


            printf( "\nProcessing round %d completed...\n", round);
            printf("Elapsed round time: %fs\n", roundTime);

            //final export on round 100
            if (round == 100){
                printf("Begin exporting...\n");
                cOut <: val;
                for (int y = 0; y < IMHT; y++){
                    for (int x = 0; x < IMWD; x++){
                        val = board[y][x];
                        cOut <: val;
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

int countNeighbours(uchar board[WORKERHT][IMWD], int y, int x){
    int neighbourCount = 0;

    for (int i = -1; i < 2; i ++){
        for (int j = -1; j < 2; j ++){
            if (!((i == 0) && (j == 0))){
                if (board[(y + j)][(x + i + IMWD) % IMWD] == ALIVECELL){
                    neighbourCount++;
                }
            }
        }
    }
    return neighbourCount;
}

// Apply rules of game of life on each cell, depending on their neighbour counts
int aliveOrDead(int neighbourCount, int currentCell){
    if (currentCell == ALIVECELL && neighbourCount < 2) return 0;
    else if (currentCell == ALIVECELL && (neighbourCount == 2 || neighbourCount == 3)) return ALIVECELL;
    else if (currentCell == ALIVECELL && neighbourCount > 3) return 0;
    else if ((currentCell == 0) && (neighbourCount == 3)) return ALIVECELL;
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
    unsigned char currentCell;
    unsigned char updatedCell;
    unsigned int aliveNeighbours = 0;
    unsigned char board[WORKERHT][IMWD];
    unsigned char newBoard[WORKERHT][IMWD];

    //initialise newBoard with 0s
    for (int y = 0; y < WORKERHT; y++){
        for (int x = 0; x < IMWD; x++){
            board[y][x] = 0;
            newBoard[y][x] = 0;
        }
    }

    while (round < MAX_ROUNDS){

        // look for tilt pause here
        // cControl :> int value;

        //populate input board
        for (int y = 0; y < WORKERHT; y++){
            for (int x = 0; x < IMWD; x++){
                cWorker :> currentCell;
                board[y][x] = currentCell;
                cWorker <: currentCell;
            }
        }

        /*if (index == 1){
            printf("WORKER BOARD 2 IN WORKER\n");
            for (int y = 0; y < WORKERHT; y++){
                for (int x = 0; x < IMWD; x++){
                    printf("%4.1d ", board[y][x]);
                }
                printf("\n");
            }
        }*/

        // get currentCell from distributor, manipulate and insert into newBoard
        for (int y = 0; y < WORKERHT; y++){
            for (int x = 0; x < IMWD; x++){
                if (y != 0 && y != (WORKERHT - 1)){
                    aliveNeighbours = countNeighbours(board, y, x);
                    newBoard[y][x] = aliveNeighbours;     //newBoard contains number of alive neighbours for each cell
                }
            }
        }

        /*//Neighbour count print
        if (index == 2){
            printf("NEIGHBOUR COUNT\n");
            for (int y = 0; y < WORKERHT; y++){
                for (int x = 0; x < IMWD; x++){
                    printf("%4.1d", newBoard[y][x]);
                }
                printf("\n");
            }
        }*/

        //use newBoard full of neighbourCounts to convert into updated cell status

        for (int y = 0; y < WORKERHT; y++){
            for (int x = 0; x < IMWD; x++){
                cWorker :> currentCell;
                currentCell = board[y][x];
                updatedCell = aliveOrDead(newBoard[y][x], currentCell);
                newBoard[y][x] = updatedCell;
                //printf("%4.1d", newBoard[y][x]);
                cWorker <: updatedCell;
            }
            //printf("\n");
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
      uchar val;
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

          printf( "-%4.1d ", line[ x ] );
        }
        _writeoutline( line, IMWD );
        printf( "DataOutStream: Line written...\n" );
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
chan cWorker[4], cButton[2], cVisualiser[3];

par {
    on tile[0]: i2c_master(i2c, 1, p_scl, p_sda, 10);  //server thread providing orientation data
    on tile[0]: orientation(i2c[0],cControl);        //client thread reading orientation data
    on tile[1]: DataInStream(infname, cInIO);          //thread to read in a PGM image
    on tile[1]: DataOutStream(outfname, cOutIO, cVisualiser[2]);       //thread to write out a PGM image
    on tile[1]: distributor(cInIO, cOutIO, cButton[0], cButton[1], cVisualiser[0], cVisualiser[1], cWorker[0], cWorker[1], cWorker[2], cWorker[3], cControl, cTimer);  //thread to coordinate work on image
    on tile[1]: worker(0, cWorker[0]);
    on tile[1]: worker(1, cWorker[1]);
    on tile[1]: worker(2, cWorker[2]);
    on tile[1]: worker(3, cWorker[3]);
    on tile[0]: buttonListener(buttons, cButton[0], cButton[1]);
    on tile[0]: showLEDs(leds, cLEDs);
    on tile[0]: visualiser(cLEDs, cVisualiser[0], cVisualiser[1], cVisualiser[2]);
    on tile[0]: timerFunction(cTimer);
    //for (int i = 0; i < 4; i++) on tile[1]: worker(i, cWorker[i]);
  }

  return 0;
}
