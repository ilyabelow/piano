/*
* TO DO:
 * Дописать объединение треков
 * Иногда продолжительность игры плитки не соответствует длине. Вероятно, из-за наложения
 * Почему плитки дрыгаются?!
 * Придумать настройку скорости (по темпу?)
 * Сделать правильно удаление последней плитки (если это вообще потом понадобится)
 * Сделать выключение всех нот при рестарте
 * Бывают треки без нот, но с разным. Надо придумать что с такими делать
 * ОБРАБОТАТЬ МЕТА СООБЩЕНИЯ АРГХ! 
 */


import javax.sound.midi.*;
import java.io.File;

Receiver rcv;
Synthesizer synth;

final int NOTE_ON = 0x90;
final int NOTE_OFF = 0x80;

final int LOADING = 132;
final int START = 133;
final int PLAYING = 134;
final int END = 135;

PFont loading_f, tile_f;
final char keys[] = new char[]{'a', 's', 'd', 'f'};
final char keys_upper[] = new char[]{'A', 'S', 'D', 'F'};
final int tiles_in_row = 4, tiles_in_col = 6;
final int col_tiles[] = new int[tiles_in_row];
final float redness_speed = 0.1; //Скорость уменьшения красноты
final int jump_T = 50, jump_A = 5; //Период и амплитуда прыганья надписи Loading, Период мигания нижних надписей
float tick_len; //Длина тика
int  offset, cur_time; //Смещение времени проигрывания из-за вступительного экрана
int w; //Ширина плитки
float redness[] = new float[tiles_in_row];
boolean pressed[] = new boolean[]{false, false, false, false};
//Индексы крайних плиток
int head = 1, tail = 1, next = 1; //Нулевая плитка не настоящая, поэтому начинаем с первой
//track_it - номер играемого трека, note_index - индекс следующего ивента
int note_index = -1;
//Количество кадров, при котором текст остаётся на экране, послепенно тускнея
int text_ticks, text_ticks_max = 30;
int mistakes;
Tile tiles[] = new Tile[]{};
int status;
float speed; //пиксели/милисекунда
JSONObject info;
String trackname;
int thr_time; //Время, необходимое плитке чтобы пройти весь экран

void setup() {
  size(400, 800);
  info = loadJSONObject("info.json");
  background(255);
  textAlign(CENTER);
  w = width/tiles_in_row;
  text_ticks = text_ticks_max;
  status = LOADING;
  loading_f = createFont("Deutsch Gothic", 35);
  tile_f = createFont("ProcessingSansPro-Regular", 2);
  textFont(loading_f);
  thread("load");
  rectMode(CORNERS); 
  try {
    synth.loadInstruments(MidiSystem.getSoundbank(new File("/home/ilyabelow/Code/sketchbook/piano/FluidR3_GM.sf2")), new Patch[]{new Patch(0, 0)});
  }
  catch(Exception e) {
  }
}

void draw() {
  background(255);
  if (status==LOADING) {
    fill(0);

    text("Loading...", width/2, height/2 + jump_A*asin(sin(map( frameCount % jump_T, 0, jump_T-1, 0, TWO_PI))));
  }

  if (status != LOADING) {
    //Рисовка линий-разделителей
    stroke(map(text_ticks, text_ticks_max, 0, 255, 127));
    for (int x = 0; x < tiles_in_row; x++) {
      line(x*w, 0, x*w, height);
    }
    line(tiles_in_row*w - 1, 0, tiles_in_row*w-1, height); //Последняя линия смещена на пиксель влево чтобы помещалась в экран. Так себе решение
    //Рисовка названия трека
    if (text_ticks > 0) {
      textSize(48);
      float alp = map(text_ticks, text_ticks_max, 0, 255, 0);
      fill(0, alp);
      text(trackname, width/16, height/8, width-(width/8), height/2);
      if (status != END) {
        textSize(21);
        text("Press any key to start", width/2, height-80);
        fill(128, alp);
        textSize(14);
        text("Press enter to choose midi", width/2, height-50);
        text("Press numbers to choose main track", width/2, height-30);
        text("Press backspace to restart", width/2, height-10);
      }
      if (status == END) {
        textSize(31);
        text("You've played", width/2, height/8-20);
        text("Tiles: "+ (tiles.length-1), width/2, height/2);
        text("Mistakes: "+ mistakes, width/2, height/2 + 36);
        textSize(21);
        text("Press backspace to restart", width/2, height-80);
      }
    }
    if (status == PLAYING && text_ticks > 0) {
      text_ticks--;
    }
    if (status == END && text_ticks < text_ticks_max) {
      text_ticks++;
    }
  }

  //Плитки
  if (status == PLAYING) {
    cur_time = millis() - offset;

    //Добавление новых плиток
    if (head < tiles.length) {
      if (tiles[head].start_time <= cur_time) { 
        head++;
      }
    }

    //Обновление плиток
    noStroke();
    for (int i = tail; i < head; i++) {
      tiles[i].move();
      tiles[i].display();
    }

    //Tile is to be deleted <- дофига крутая конструкция?!
    if (tail < tiles.length) {
      if (tiles[tail].kill_me_please) {
        tiles[tail] = null; 
        tail++;
      }
    }
    if (tail == tiles.length) {
      status = END;
      textSize(32);
      fill(0);
    }
    //Рисовка красноты
    for (int x = 0; x < tiles_in_row; x++) {
      if (redness[x] > 0) {
        fill(255, 0, 0, sin(redness[x])*200);
        rect(x*w, 0, x*w+w, height);
        redness[x] -= redness_speed;
        if (redness[x] < 0) {
          redness[x] = 0;
        }
      }
    }
  }
}

void restart() {//Надо добавить функцию отключения всех нот
  head = tail = next = 1;
  status = START;
  tiles = assembleTiles(info.getInt("track"));
  text_ticks = text_ticks_max;
  for (int i = 0; i < tiles_in_row; i++) { 
    col_tiles[i] = 0;
  }
}

void ouch(int row) {
  redness[row] = HALF_PI;
  mistakes++;
} 

void sendNext() {
  next++;
  if (next < tiles.length) {
    tiles[next].need_press = true;
  }
}

void keyPressed() {
  if (status == PLAYING) {
    for (int i = 0; i < tiles_in_row; i++) {
      if (keys[i]== key && pressed[i] == false) {
        pressed[i] = true;
        if (next < head) {
          if (tiles[next].col == i) {
            tiles[next].press(millis() - offset);
            col_tiles[i] = next;
            sendNext();
          } else {
            ouch(i);
          }
        } else {
          ouch(i);
        }
      }
    }
    if (keyCode == BACKSPACE) {
      restart();
    }
  } else if (status == START ) {
    if ( keyCode == ENTER) {
      String last_path = info.getString("last");
      last_path = last_path.substring(0, last_path.length() - trackname.length() - 4) + "." ; //+ "."? Чего?..
      selectInput("Select MIDI", "loadMidi", new File(last_path));
    } else if (keyCode > 47 && keyCode < 58) {
      tiles = assembleTiles(keyCode - 48);
      info.setInt("track", keyCode - 48);
      saveJSONObject(info, "data/info.json");
    } else if (keyCode != BACKSPACE) {
      offset = millis();
      status = PLAYING;
      tiles[0].playAddNotes(synth.getMicrosecondPosition());
    }
  } else if (status == END ) {
    if (keyCode == BACKSPACE) {
      restart();
    }
  }
}

void keyReleased() {
  for (int i = 0; i < pressed.length; i++) {
    if (keys[i]== key && pressed[i] == true) {
      pressed[i] = false;
      if (tiles[col_tiles[i]] != null) {
        tiles[col_tiles[i]].release(millis() - offset);
      }
    }
  }
}

void load() {
  try {
    synth = MidiSystem.getSynthesizer();
    synth.open();
    rcv = synth.getReceiver();
  }
  catch(MidiUnavailableException e) {
    println("Opening synthesizer failed");
    exit();
  }
  loadMidi(new File(info.getString("last")));

  textFont(tile_f);
  status = START;
}

void loadMidi(File f) {
  if (f == null) {
    println("No file was chosen");
    return;
  }
  if ( !f.getName().substring(f.getName().length() - 4).equals(".mid")) {
    println("File is not a midi file");
    return;
  }
  trackname = f.getName().substring(0, f.getName().length() - 4);
  pullOutNotes(f);
  if (!f.getAbsolutePath().equals(info.getString("last"))) {
    info.setInt("track", 0);
    info.setString("last", f.getAbsolutePath());
    saveJSONObject(info, "data/info.json");
  }
  tiles = assembleTiles(info.getInt("track"));
}
