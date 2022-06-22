


class Tile {
  int col, messages_count, duration;
  int all_duration; //ВРЕМЕННОЕ РЕШЕНИЕ
  int start_time, press_time, release_time;//Это всё - абсолютное время относительно offset
  float y, h, term; //term = terminator = линия, разделяющая освещённую и тёмную сторону планеты = и плитки
  boolean kill_me_please, need_press, pressed, released;
  Note[] mainNotes;
  Note[] additionalNotes;

  Misc[] misc; //То же название, что и у глобальной переенной... проблемы?

  Tile(int _time) {
    start_time = _time;
    mainNotes = new Note[]{};
    additionalNotes = new Note[]{};
    misc = new Misc[]{};
  }



  void move() {
    y = (float)(cur_time - start_time)*speed; //Значение y каждый раз вычисляется заногу, предыдущие значения не учитываются
    if (pressed && cur_time >= press_time + duration && duration > 0) {//Последнее условие - для нулевой плитки
      release( press_time + duration);
    } 
    if (released) {
      term = (float)(cur_time - release_time + press_time - start_time)*speed; //Чёт сложная формула получилась
    }
    //Плитка коснулась края экрана и не нажата - увы!
    if (cur_time >= start_time + thr_time && need_press) {
      press(start_time + thr_time); 
      ouch(col);
      sendNext();
    }
    //Плитка ушла за пределы экрана - удалить!  \/ ВРЕМЕННОЕ РЕШЕНИЕ, ведь не учитывается доп высота
    if (cur_time >= start_time + thr_time + duration && cur_time - start_time > all_duration) { //Удаляется когда прошло время всех нот с момента ПОЯВЛЕНИЯ!
      kill_me_please = true;
      release(start_time + thr_time + duration);
    }
  }

  void display() {
    if (pressed || released) {
      fill(127);
      rect(col*w, y, col*w + w, term);
      fill(0);
      rect(col*w, term, col*w + w, y-h);
    } else {
      fill(0);
      rect(col*w, y, col*w + w, y-h);
    }
    if (need_press) {
      textSize(30);
      fill(255);
      text(keys_upper[col], col *width/tiles_in_row + (width/tiles_in_row)/2, y - h/2 + 10); //+10 для того, чтобы рисовалось прямо в середине ВРЕМЕННОЕ РЕШЕНИЕ
    }
  }

  void press(int t) {
    long note_t = synth.getMicrosecondPosition();
    for (int i = 0; i < mainNotes.length; i++) {
      mainNotes[i].enable(note_t);
    }    
    for (int i = 0; i < misc.length; i++) {
      rcv.send(misc[i].ms, note_t + (misc[i].time-start_time)*1000);
    }    
    need_press = false;
    pressed = true;
    press_time = t;
    term = (float)(press_time - start_time)*speed;
    playAddNotes(note_t);
  }

  void release(int t) { 
    if (!released) {
      long note_t = synth.getMicrosecondPosition();
      for (int i = 0; i < mainNotes.length; i++) {
        mainNotes[i].disable(note_t);
      }  
      release_time = t;
      pressed = false;
      released = true;
    }
  }

  void playAddNotes(long note_t) {
    for (int i = 0; i < additionalNotes.length; i++) {
      additionalNotes[i].playFull(note_t + (additionalNotes[i].start - start_time)*1000);
    }
  }

  void addMainNote(Note n) {
    mainNotes = (Note[]) append(mainNotes, n);
    all_duration = max(all_duration, n.duration);
    duration = max(duration, n.duration);
  }
  void addAdditionalNote(Note n) {
    additionalNotes = (Note[]) append(additionalNotes, n);
    all_duration = max(all_duration, n.duration);
  }

  void addMisc(Misc m) {
    misc = (Misc[]) append(misc, m);
  }
}





class Note {
  int start, finish, duration, note, track = -1;
  ShortMessage on, off;
  boolean empty;


  Note(long tick, int _note, ShortMessage _on) {
    start = (int)(tick*tick_len);
    note = _note;
    on = _on;
  }

  void setOff(ShortMessage _off, long tick) {
    off = _off;
    finish = (int)(tick*tick_len);
    if (finish == start) {
      empty = true;
    }
    duration = finish - start;
  }

  void enable(long t) { 
    rcv.send(on, t);
  }

  void disable(long t) {
    rcv.send(off, t);
  }

  void playFull(long t) {
    rcv.send(on, t);
    rcv.send(off, t + duration * 1000);
  }
}

class Misc {
  ShortMessage ms;
  int time, track = -1;

  Misc(ShortMessage _ms, long tick) {
    time = (int)(tick*tick_len);
    ms = _ms;
  }
}