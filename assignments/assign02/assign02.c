#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <math.h>
#include "pico/stdlib.h"
#include <string.h>
#include "hardware/pio.h"
#include "hardware/clocks.h"
#include "ws2812.pio.h"
//#include "hardware/watchdog.h"

//////////// GLOBAL VARIABLES AND FUNCTIONN DECLARATIONS  ///////////////////////////////////////

void main_asm();
void interruptHandler2();
void word_input();
void sleeper();

int match;
int count_code;
char code[100] = "";
char sequence[100]="";
int sequence_index;

uint64_t singleTotalTime;
uint64_t singleTotalTimeStart;

#define IS_RGBW true        // Will use RGBW format
#define NUM_PIXELS 1        // There is 1 WS2812 device in the chain
#define WS2812_PIN 28       // The GPIO pin that the WS2812 connected to

char* morse_chars[] = {".-", "-...", "-.-.", "-..", ".", "..-.", "--.", "....", "..", 
".---", "-.-", ".-..", "--", "-.", "---", ".--.", "--.-", ".-.", "...", "-", "..-", "...-", 
".--", "-..-", "-.--", "--..", "-----", ".----", "..---", "...--", "....-", ".....", "-....",
 "--...", "---..", "----."};

char* alphanumeric_chars[] = {"A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", 
 "Q", "R", "S", "T", "U", "V", "W", "X", "Y", "Z", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9"};


char* morse_words_chars[] =  {"-.. --- --.","-.-. .- -","-- .- -.","-.-. .- .-.","... ..- -.","... -.- -.--",".--. . -.",
 "-... .- -","-.- . -.--","..-. .-.. -.--"};
   
char* morse_words[] ={"dog", "cat", "man", "car", "sun", "sky", "pen", "bat", "key", "fly"};


int Correct_Counter = 0 ;
int  Wrong_Counter = 0;
int Gained_Lives = 0;
int Remaining_Lives=3;

////////////////////////////////////////////////////////////////////////////////////////////////


//////////// UI AND PRINT STATEMENTS  /////////////////////////////////////////////////////////


#define WELCOME "************************************************************************************\n*									           *\n*		LEARN MORSE CODE - An interactive game on the RP2040               *\n*									           *\n************************************************************************************\n*										   *\n*	Welcome to our game! This code was written by Group 27                     *\n*						                	  	   *\n*	  Here are some instructions to get you started: 		           *\n*										   *\n* 1. Select your level by entering the Morse code for the level number (for now,   *\n*    the codes are provided).                                                      *\n* 2. Press the GP21 button on the MAKER-PI-PICO board briefly (255ms or less)      *\n*    to enter a dot, and press it for a longer duration (longer than 255ms) to     *\n*    enter a dash.                                                                 *\n* 3. You start with 3 lives. Gain a life for each correct answer (up to 3 lives)   *\n*    and lose a life for each incorrect answer. The RGB LED shows your game        *\n*    status:                                                                       *\n*   				GREEN: 3 lives                                     *\n*   			        YELLOW: 2 lives                                    *\n*                               ORANGE: 1 life                                     *\n*                               RED: 0 lives, GAME OVER                            *\n*										   *\n************************************************************************************\n" // welcome msg


void Display_Welcome_Messages()
{
    printf(WELCOME);
}

void livesleft(int lives)
{
    if(lives == 0 ){
        printf("\n");
        printf("            +---------------------------------+\n");
        printf("            |                                 |\n");
        printf("            |      0 Lives remaining          |\n");
        printf("            |     Better luck next time       |\n");
        printf("            |                                 |\n");
        printf("            +---------------------------------+\n");
        printf("\n");
    }
    else if (lives <= 3){
        printf("\n");
        printf("            +---------------------------------+\n");
        printf("            |                                 |\n");
        printf("            |      %d Lives remaining          |\n", lives);
        printf("            |  You're doing well . keep going |\n");
        printf("            |                                 |\n");
        printf("            +---------------------------------+\n");
        printf("\n");
    }
}
void invalid_input(){
    printf("            +----------------------------------------+\n");
    printf("            |                                        |\n");
    printf("            |        Invalid Input, Try Again        |\n");
    printf("            |                                        |\n");
    printf("            +----------------------------------------+\n");
}

void questionUI(char* word , char* morse)
{
        printf("\n");
        printf("            +----------------------------------------------------------+\n");
        printf("            |     The following is the character and its morse code :  |\n");
        printf("            |          The Character    :       %s                      |\n", word);
        printf("            |          The morse code   :       %s                      |\n",morse );
        printf("            |           !! BEST OF LUCK !!                             |\n");
        printf("            +----------------------------------------------------------+\n");
        printf("\n");
}

void stats(int Correct_Counter , int Wrong_Counter , int Gained_Lives){
        printf("\n");
        Remaining_Lives = Correct_Counter - Wrong_Counter;
        int percentage_lives = Correct_Counter/(Correct_Counter + Wrong_Counter);
        printf("*----------------------------------------*\n");
        printf("*             Statistics Table           *\n");
        printf("*             Correct answers: %d        *\n", Correct_Counter);
        printf("*             Wrong answers: %d          *\n", Wrong_Counter);
        printf("*             Gained Lives: %d           *\n", Gained_Lives);
        printf("*   percentage of correctness: %d        *\n", percentage_lives * 100);
        printf("*----------------------------------------*\n");
        printf("\n");
}


void input_question(char* morse )
{
        printf("\n");
        printf("            +-----------------------------------------------------+\n");
        printf("            |             write the morse code for %s :            |\n", morse);
        printf("            |                 !! BEST OF LUCK !!                  |\n");
        printf("            +-----------------------------------------------------+\n");
        printf("\n");
}

void correct_answer()
{
        printf("\n");
        printf("            +-----------------------------------------------------+\n");
        printf("            |                  Congurtulations!                   |\n");
        printf("            |            CORRECT ANSWER. NEXT QUESTION :          |\n");
        printf("            |                 !! BEST OF LUCK !!                  |\n");
        printf("            +-----------------------------------------------------+\n");
        printf("\n");
}

void game_won_display()
{
    printf("                +----------------------------------------+\n");
    printf("                |                                        |\n");
    printf("                |   Congurtulations! You won the game!   |\n");
    printf("                |                                        |\n");
    printf("                +----------------------------------------+\n");
}

void level_complete()
{
    printf("                +----------------------------------------------+\n");
    printf("                |                                              |\n");
    printf("                |   Congurtulations! You Finished the Level!   |\n");
    printf("                |              Next Level Coming UP!           |\n");
    printf("                +----------------------------------------------+\n");
}

void game_over_display()
{
    printf("                +----------------------------------+\n");
    printf("                |                                  |\n");
    printf("                |   Sorry, you lost the game!      |\n");
    printf("                |                                  |\n");
    printf("                +----------------------------------+\n");
}

void incorrectinput()
{
    printf("\n");
    printf("\n");
    printf("                +-----------------------------------------------+\n");
    printf("                |                INCORRECT ANSWER:              |\n");
    printf("                |       this did not match any sequence         |\n");
    printf("                +-----------------------------------------------+\n");
    printf("                \n");
    printf("                +----------------------------------+\n");
    printf("                |     Wrong! One life was taken.   |\n");
    printf("                +----------------------------------+\n");
}

void printUI() {
  printf(WELCOME,"\n");
  printf("\n\n\n");
  printf("                  +-------------------------------------------+\n");
  printf("                  |             ASSIGNMENT #02                |\n");
  printf("                  +-------------------------------------------+\n");
  printf("                  | #       #######     #    ######   #     # |\n");
  printf("                  | #       #          # #   #     #  ##    # |\n");
  printf("                  | #       #         #   #  #     #  # #   # |\n");
  printf("                  | #       #######  #     # ######   #  #  # |\n");
  printf("                  | #       #        ####### #    #   #   # # |\n");
  printf("                  | #       #        #     # #     #  #    ## |\n");
  printf("                  | ####### #######  #     # #      # #     # |\n");
  printf("                  |                                           |\n");
  printf("                  | #     # #######  ######   #####   ####### |\n");
  printf("                  | ##   ## #     #  #     # #     #  #       |\n");
  printf("                  | # # # # #     #  #     # #        #       |\n");
  printf("                  | #  #  # #     #  ######   #####   ####### |\n");
  printf("                  | #     # #     #  #   #         #  #       |\n");
  printf("                  | #     # #     #  #    #  #     #  #       |\n");
  printf("                  | #     # #######  #     #  #####   ####### |\n");
  printf("                  |                                           |\n");
  printf("                  |       ######  ####### ######  #######     |\n");
  printf("                  |      #        #     # #     # #           |\n");
  printf("                  |      #        #     # #     # #           |\n");
  printf("                  |      #        #     # #     # #######     |\n");
  printf("                  |      #        #     # #     # #           |\n");
  printf("                  |      #        #     # #     # #           |\n");
  printf("                  |       ######  ####### ######  #######     |\n");
  printf("                  +-------------------------------------------+\n");
  printf("                  |   USE GP21 TO ENTER A SEQUENCE TO BEGIN   |\n");
  printf("                  |     \".----\" - LEVEL 01 - CHARS (EASY)     |\n");
  printf("                  |     \"..---\" - LEVEL 02 - CHARS (HARD)     |\n");
  printf("                  |     \"...--\" - LEVEL 03 - WORDS (EASY)     |\n");
  printf("                  |     \"....-\" - LEVEL 04 - WORDS (HARD)     |\n");
  printf("                  +-------------------------------------------+\n");
  printf("                  | Members:-Ammar,Rehaan,Saish,Tanuj,Vaibhav |\n");
  printf("                  +-------------------------------------------+\n");
  printf("\n\n\n");
}

////////////////////////////////////////////////////////////////////////////////////////////////

//////////// LED, TIMER, WATCHDOG AND BUTTON INITIALIZATION AND FUNCTIONS //////////////////////


int asm_gpio_get(int pin) {
    return gpio_get(pin);
}


// Initialise a GPIO pin – see SDK for detail on gpio_init()
void asm_gpio_init(uint pin) {
    gpio_init(pin);
}

// Set direction of a GPIO pin – see SDK for detail on gpio_set_dir()
void asm_gpio_set_dir(uint pin, bool out) {
    gpio_set_dir(pin, out);
}

// Enable falling-edge interrupt – see SDK for detail on gpio_set_irq_enabled()
void asm_gpio_set_irq(uint pin)
{
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_FALL, true);
    gpio_set_irq_enabled(pin, GPIO_IRQ_EDGE_RISE, true);
}

// Get a timestamp in milliseconds
int get_time_in_ms()
{
    absolute_time_t time = get_absolute_time();
    return to_ms_since_boot(time);
}

// Find the time difference in milliseconds
int get_time_difference(int end_time, int start_time)
{
    return (end_time - start_time);
}


void startTimer() {
    singleTotalTimeStart = time_us_64();
}



void endTimer() {
    uint64_t singleTotalTimeEnd;
    singleTotalTimeEnd = time_us_64();
    singleTotalTime = (double) (singleTotalTimeEnd - singleTotalTimeStart);
    extern uint64_t singleTotalTime;
}

// void watchdog_init()
// {
//     if (watchdog_caused_reboot())
//     { // check if reboot was due to watchdog timeout
//         printf("\nNo input was detected for timeout period. Rebooted by watchdog\n");
//     }
//     if (watchdog_enable_caused_reboot())
//     { // check if enabling watchdog caused reboot
//         printf("\nChip reboot due to watchdog enable\n");
//     }
//     watchdog_enable(0x7fffff, 1); // enable the watchdog timer to max time (approx 8.3 secs), pause on debug
//     watchdog_update();
// }




////////////////////////////////////////////////////////////////////////////////////////////////


//////////// LED CHANGING COLOURS  ////////////////////////////////////////////////////////////

/**
 * @brief Wrapper function used to call the underlying PIO
 *        function that pushes the 32-bit RGB colour value
 *        out to the LED serially using the PIO0 block. The
 *        function does not return until all of the data has
 *        been written out.
 * 
 * @param pixel_grb The 32-bit colour value generated by urgb_u32()
 */
static inline void put_pixel(uint32_t pixel_grb) {
    pio_sm_put_blocking(pio0, 0, pixel_grb << 8u);
}


/**
 * @brief Function to generate an unsigned 32-bit composit GRB
 *        value by combining the individual 8-bit paramaters for
 *        red, green and blue together in the right order.
 * 
 * @param r     The 8-bit intensity value for the red component
 * @param g     The 8-bit intensity value for the green component
 * @param b     The 8-bit intensity value for the blue component
 * @return uint32_t Returns the resulting composit 32-bit RGB value
 */
static inline uint32_t urgb_u32(uint8_t r, uint8_t g, uint8_t b) {
    return  ((uint32_t) (r) << 8)  |
            ((uint32_t) (g) << 16) |
            (uint32_t) (b);
}


/**
 * @brief EXAMPLE - WS2812_RGB
 *        Simple example to initialise the NeoPixel RGB LED on
 *        the MAKER-PI-PICO and then flash it in alternating
 *        colours between red, green and blue forever using
 *        one of the RP2040 built-in PIO controllers.
 * 
 * @return int  Application return code (zero for success).
 */

 // Set the color to red at half intensity
void set_red() 
{
   put_pixel(urgb_u32(0x3F, 0x00, 0x00));
}

// Set the color to green at half intensity
void set_green() 
{
   put_pixel(urgb_u32(0x00, 0x3F, 0x00));
}

// Set the color to blue at half intensity
void set_blue() 
{
    put_pixel(urgb_u32(0x00, 0x00, 0x3F));
}
        
//Yellow
void set_yellow() 
{
   put_pixel(urgb_u32(0xAF, 0xAF, 0x00));
}

//Orange
void set_orange() 
{
   put_pixel(urgb_u32(0xAC, 0x46, 0x00)); 
}
        
        //Off
 void set_off() 
{
   put_pixel(urgb_u32(0x00, 0x00, 0x00));
}

void set_lights(int lives){
    if (lives==3){
        set_green();
    }
    else if( lives == 2)
        set_yellow();
    else if (lives == 1)
        set_orange();
    else if (lives == 0)
        set_red();
    else
        set_blue();
}

////////////////////////////////////////////////////////////////////////////////////////////////


//////////// QUESTION GENERATION  /////////////////////////////////////////////////////////////

 char** getQuestion1(int level)
{
    int random_index;
    while (1) {
        // Generate a random number between 0 and 35 (inclusive)
        random_index = rand() % 36;
        if (random_index >= 0 && random_index < 36) {
            break;
        }
    }
    char *random_char_an = alphanumeric_chars[random_index];
    char *random_char_morse = morse_chars[random_index];
    //printf("The alphanumeric charcter to enter: %c\n", random_char_an);
    if (level==1) {
        //printf("Its morse equivalent : %c\n,", random_char_morse);
        questionUI(random_char_an,random_char_morse);
    }
    // Get the alphanumeric character at the random index
    //const char* random_char = alphanumeric_chars[random_index];
    else {
        input_question(random_char_an);
    }
   // char ** p1 = &random_char_an;
    return &alphanumeric_chars[random_index];
}



char** getQuestion2(int level)
{
    int random_index;
    while (1) {
        // Generate a random number between 0 and 9 (inclusive)
        random_index = rand() % 10;
        if (random_index >= 0 && random_index < 10) {
            break;
        }
    }
    // Get the word and its Morse code at the random index
    char *random_char_morse  = morse_words_chars[random_index];
    char *random_word = morse_words[random_index];
    //printf("The random word to enter: %s\n",random_word);
   // printf("The random morse char to enter: %s\n",random_char_morse);
    if (level==3) {
        //printf("Its morse equivalent : %c\n,", random_char_morse);
        questionUI(random_word,random_char_morse);
    }
    // Get the alphanumeric character at the random index
    //const char* random_char = alphanumeric_chars[random_index];
    else {
        input_question(*random_char_morse);
    }
    char ** p1 = &random_char_morse;

    return p1;
}

////////////////////////////////////////////////////////////////////////////////////////////////

//////////// USER INPUT HANDLING  /////////////////////////////////////////////////////////////

void make_sequence(int num)
{
    if (num==1)
     {
        sequence[sequence_index]='.';
        sequence_index++;
        printf(".");
     }
    else if(num==2)
    {
        sequence[sequence_index]='-';
        sequence_index++;
        printf("-");
    }
    else if(num==3)
    {
        sequence[sequence_index]=' ';
        sequence_index++;
        printf(" ");
    }
    
}

char** level4GetInput()
{
    word_input();
    char* p1 = sequence;
    char** p2 = &p1;
    return p2;
 //When this function is called it will call rehaan's subroutine which will completely make the input in sequence and we 
 // just need to use it


}

 // Adjust the size as needed

void get_type(int num){
    match = num;
}

char ** getInput(){    
    char text[100][100]={};
    int isWord;
    isWord = 0;
    int count = 0;
    
    count_code = 0;
    do {
        // printf("Type the given morse code: \"... ..- -.\"\n");
        // char** vaibhav = level4GetInput();
        // printf("You entered: %s\n", vaibhav[0]);
        interruptHandler2();
        if (match == 1) {
            code[count_code] = '.';
            count_code++;
            printf(".");
            //strcat(code, ".");
        } else if (match == 2) {
            code[count_code]  = '-';
            //strcat(code, "-");
            count_code++;
            printf("-");

        } else if (match == 3) {
            isWord = 1;
            strcpy(text[count], code);
            code[0] = '\0';
            count++;
            printf(" ");
        }
    } while(match != 4);

    printf("Input: %s\n",code);

    if (isWord == 0 || isWord == 3){
        for (int i = 0; i < 36; i++){
            if (strcmp(morse_chars[i], code) == 0){
                printf("char: %s\n", alphanumeric_chars[i]);
               // char temp = alphanumeric_chars[i];
               
                char* p1 = alphanumeric_chars[i];
                char** p2 = &p1;
                return p2;
            }
        }
        char error[] = "error";
        char* p1 = error;
        char** p2 = &p1;
        return p2;
    }
    else if (isWord == 1){
        char word[100];
        for (int i = 0; i < count; i++){
            for (int j = 0; j < 36; j++){
                if (strcmp(morse_chars[j], text[i])==0){
                    char* temp = alphanumeric_chars[j];
                    strncat(word, temp, 1);
                }
            }
        }
        if (strcmp(word,"")==0){
            char error[] = "error";
            char* p1 = error;
            char** p2 = &p1;
            return p2;
        }
        else {
            printf("Input: %s\n",word);
            char* p1 = word;
            char** p2 = &p1;
            return p2;
        }
    }
    char error[] = "error";
    char* p1 = error;
    char** p2 = &p1;
    return p2;
}

////////////////////////////////////////////////////////////////////////////////////////////////

//////////// GAME IMPLEMENTATION  /////////////////////////////////////////////////////////////
int select_level(){
    char** ans  = getInput();
    int num = atoi(*ans);
    return num;
}
void reset_code(){
    for(int i = 0 ; i<count_code; i++){
        code[i] = '\0';
    }
}


 void game(){
    set_lights(-1);
    int lives = 3;
   // int level = select_level();
    int level =1;
    int correctAns;
    bool gameOver = false;
    while(lives>0 || !gameOver){
        set_lights(lives);
        switch(level){
            case 1:
                correctAns = 0;
                for (int i = 0; i<5 && level ==1  && lives>0; i++){
                    reset_code();
                    livesleft(lives);
                    char **ques = getQuestion1(1);
                    //sleeper();
                    char** ans  = getInput();
                    if (ans==0x2003f808){
                        if (lives==1)
                            gameOver = true;
                        lives--;
                        Wrong_Counter++;
                        incorrectinput();
                        break;
                    }
                    else if (strcmp(ques,ans)==0){
                        correctAns++;
                        Correct_Counter++;
                        if (lives<3){
                            lives++;
                            Gained_Lives++;
                        }
                        correct_answer();
                        if (correctAns==5){
                            level = 2;
                            level_complete();
                            break;
                        }
                    }
                    else{
                        if (lives==1)
                            gameOver = true;
                        lives--;
                        Wrong_Counter++;
                        incorrectinput();
                        break;
                    }
                    set_lights(lives);
                    }
            break;

            case 2:
                correctAns = 0;
                for (int i = 0; i<5 && level ==2  && lives>0 && gameOver==false; i++){
                    reset_code();
                    livesleft(lives);
                    char **ques = getQuestion1(2);
                    //sleeper();
                    char** ans  = getInput();
                    if (ans==0x2003f808){
                        if (lives==1)
                            gameOver = true;
                        lives--;
                        Wrong_Counter++;
                        incorrectinput();
                        break;
                    }
                    else if (strcmp(ques,ans)==0){
                        correctAns++;
                        Correct_Counter++;
                        if (lives<3){
                            lives++;
                            Gained_Lives++;
                        }
                        correct_answer();
                        if (correctAns==5){
                            gameOver = true;
                            game_won_display();
                            break;
                            level = 3;
                        }
                    }
                    else{
                        if (lives==1)
                            gameOver = true;
                        lives--;
                        Wrong_Counter++;
                        incorrectinput();
                        break;
                    }
                    set_lights(lives);
                    }
            break;

            case 3:

               correctAns = 0;
                for (int i = 0; i<5 && level ==3  && lives>0; i++){
                    reset_code();
                    livesleft(lives);
                    char **ques = getQuestion2(3);
                    //sleeper();
                    char** ans  = level4GetInput();
                    if (ans==0x2003f808){
                        if (lives==1)
                            gameOver = true;
                        lives--;
                        Wrong_Counter++;
                        incorrectinput();
                        break;
                    }
                    else if (strcmp(ques,ans)==0){
                        correctAns++;
                        Correct_Counter++;
                        if (lives<3){
                            lives++;
                            Gained_Lives++;
                        }
                        correct_answer();
                        if (correctAns==5){
                            level = 4;
                            level_complete();
                        }
                    }
                    else{
                        if (lives==1)
                            gameOver = true;
                        lives--;
                        Wrong_Counter++;
                        incorrectinput();
                        break;
                    }
                    set_lights(lives);
                    }
            break;

            case 4:

               correctAns = 0;
                for (int i = 0; i<5 && level ==3  && lives>0; i++){
                    reset_code();
                    livesleft(lives);
                    char **ques = getQuestion2(3);
                    //sleeper();
                    char** ans  = getInput();
                    if (ans==0x2003f808){
                        if (lives==1)
                            gameOver = true;
                        lives--;
                        Wrong_Counter++;
                        incorrectinput();
                        break;
                    }
                    else if (strcmp(ques,ans)==0){
                        correctAns++;
                        Correct_Counter++;
                        if (lives<3){
                            lives++;
                            Gained_Lives++;
                        }
                        correct_answer();
                        if (correctAns==5){
                            gameOver = true;
                            game_won_display();
                            break;
                        }
                    }
                   else{
                        if (lives==1)
                            gameOver = true;
                        lives--;
                        Wrong_Counter++;
                        incorrectinput();
                        break;
                    }
                    set_lights(lives);
                    }
            break;

            case 0:
                invalid_input();
                break;
        }
        
    }
    if(lives==0){
        game_over_display();
    }
    stats(Correct_Counter , Wrong_Counter , Gained_Lives);

 }

 
////////////////////////////////////////////////////////////////////////////////////////////////

//////////// MAIN /////////////////////////////////////////////////////////////////////////////
                            
int main() 
{ 
  stdio_init_all();
  printUI();
  //watchdog_init();
  PIO pio = pio0;
  uint offset = pio_add_program(pio, &ws2812_program);
  ws2812_program_init(pio, 0, offset, WS2812_PIN, 800000, IS_RGBW);
  //watchdog_update();
  main_asm();

  return 0;
}

////////////////////////////////////////////////////////////////////////////////////////////////