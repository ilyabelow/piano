Note[] notes = new Note[]{}; //<>//
Misc[] misc = new Misc[]{};
int tracks;

void pullOutNotes(File f) {
  Note[][] all_notes = new Note[][]{};
  Misc[][] all_misc = new Misc[][]{};
  Sequence sequence = null;
  try {
    sequence = MidiSystem.getSequence(f);
  }
  catch (IOException eo) {
    return;
  } 
  catch (InvalidMidiDataException eo) {
    return;
  }
  tick_len = (float)sequence.getMicrosecondLength() / sequence.getTickLength()/1000.0;
  Track[] tracks_boring = sequence.getTracks();
  int empty_notes = 0;
  for (int q = 0; q < tracks_boring.length; q++) { 
    int open[] = new int[128]; 
    for (int i = 0; i < 128; i++) {
      open[i] = -1; //-1 = нота закрыта, остальные числа - индексы
    }
    //Для каждого трека свой список нот
    Note notes_new[] = new Note[]{};
    Misc misc_new[] = new Misc[]{};

    for (int i = 0; i < tracks_boring[q].size(); i++) {
      MidiEvent ev = tracks_boring[q].get(i);
      MidiMessage ms = ev.getMessage();
      //Игнор мета-сообщений ТУПОСТЬ
      if (!(ms instanceof ShortMessage)) {
        continue;
      }

      ShortMessage m = (ShortMessage) ms;
      //Не включает и не выключает? В кучу!
      if (m.getCommand() != NOTE_ON && m.getCommand() != NOTE_OFF) {
        misc_new = (Misc[])append(misc_new, new Misc(m, ev.getTick()));
        continue;
      }

      int n = m.getData1(); //Нота
      if (m.getCommand() == NOTE_ON && m.getData2() != 0) {
        if (open[n] == -1) {
          //Нота закрыта - открываем
          open[n] = notes_new.length;
          notes_new = (Note[])append(notes_new, new Note(ev.getTick(), n, m));
        } else {
          // println("Нота нажимается без выключения -_-");
          if (notes_new[open[n]].on.getChannel() != m.getChannel()) { //Ну а вдруг
            println("Чёрт, бывают таки разные каналы в одном и тои же треке :(");
          }
          //Насильно создаём закрывающее сообщение
          ShortMessage mo = m;
          try {
            mo = new ShortMessage(NOTE_OFF, m.getChannel(), m.getData1(), m.getData2());
          }
          catch (InvalidMidiDataException eo) {
            println(":(");
          }
          notes_new[open[n]].setOff(mo, ev.getTick());
          if (notes_new[open[n]].empty) {
            empty_notes++;
          }
          //Добавляем как обычно
          open[n] = notes_new.length;
          notes_new = (Note[])append(notes_new, new Note(ev.getTick(), n, m));
        }
      } else {
        if (open[n] != -1) {
          //С удалением попроще
          notes_new[open[n]].setOff(m, ev.getTick());
          if (notes_new[open[n]].empty) {
            empty_notes++;
          }
          open[n] = -1;
        } else {
          //println("Уже отжатая нота отжимается -_-");
        }
      }
    }
    //Если трек состоял только из мета-сообщений - то вообще его игнорим
    if (notes_new.length != 0 || misc_new.length != 0) {
      all_notes = (Note[][])append(all_notes, notes_new);
      all_misc = (Misc[][])append(all_misc, misc_new);
    }
  }  
  tracks = all_notes.length;
  //Проигрыватель
  //for (int t = 0; t < notes.length; t++) {
  //  for (int i = 0; i < notes[t].length; i++) {
  //    Note n = notes[t][i];
  //    rcv.send(n.on, n.start*1000 + 1000000);
  //    rcv.send(n.off, n.finish*1000 + 1000000);
  //  }
  //  for (int i = 0; i < misc[t].length; i++) {
  //    rcv.send(misc[t][i].ms, misc[t][i].time*1000 + 1000000);
  //  }
  //}

  //Теперь все ноты надо смешать по порядку в один массив
  int notes_len = 0, misc_len = 0;
  for (int i = 0; i < all_notes.length; i++) {
    notes_len += all_notes[i].length;
    misc_len += all_misc[i].length;
  }
  notes_len -= empty_notes;
  notes = new Note[notes_len];
  misc = new Misc[misc_len];
  //Сперва для нот
  int[] index = new int[tracks];
  for (int i = 0; i < notes_len; i++) {
    int min = 100000000;
    int t = -1;
    for (int j = 0; j < tracks; j++) {
      if (index[j] >= all_notes[j].length) {
        continue;
      }
      while (all_notes[j][index[j]].empty) {
        index[j]++;
      }
      if (all_notes[j][index[j]].start < min) {
        min = all_notes[j][index[j]].start;
        t = j;
      }
    }
    all_notes[t][index[t]].track = t;
    notes[i] = all_notes[t][index[t]];
    index[t]++;
  }
  //Потом для всего остального
  index = new int[tracks];
  for (int i = 0; i < misc_len; i++) {
    int min = 100000000;
    int t = -1;
    for (int j = 0; j < tracks; j++) {
      if (index[j] >= all_misc[j].length) {
        continue;
      }
      if (all_misc[j][index[j]].time < min) {
        min = all_misc[j][index[j]].time;
        t = j;
      }
    }
    all_misc[t][index[t]].track = t;
    misc[i] = all_misc[t][index[t]];
    index[t]++;
  }
}









Tile[] assembleTiles(int main_track) {
  main_track = constrain(main_track, 0, notes.length-1);
  //Перменные, отвечающие за подсчёт скорости
  //IntDict durations_max = new IntDict(); //Максимум
  //int[] durations_med = new int[]{};
  int duration_avg = 0;

  Tile[] tiles = new Tile[]{};
  Tile tile = new Tile(0); //В самую первую плитку запихивается всё то, что происодит до первой ноты
  int inote = 0, imisc = 0, time = -1;
  for (int i = 0; i < misc.length; i++) {
    if (misc[i].time <= notes[0].start) {
      tile.addMisc(misc[i]);
    } else {
      imisc = i;
      break;
    }
  }
  int clen = notes.length + misc.length;
  for (int i = imisc; i < clen; i++) {
    //Not The Smartest Choice
    boolean now_goes_note = true;
    if (imisc < misc.length && inote < notes.length) {
      if (misc[imisc].time < notes[inote].start) { //Если misc идёт раньше чем нота, то обрабатываем misc
        now_goes_note = false;
      }
    } else if (inote >= notes.length) { //То же если ноты просто окнчились
      now_goes_note = false;
    }
    //int g = 1/0; 479
    //Если нота идёт раньше или кончились misc, то по умолчанию обрабатываем ноты
    if (now_goes_note) {
      if (notes[inote].track != main_track) {
        tile.addAdditionalNote(notes[inote]);
      } else
        if (time < notes[inote].start) {
          time = notes[inote].start;
          tiles = (Tile[]) append(tiles, tile);
          tile = new Tile(time);
          tile.addMainNote(notes[inote]);
          //СТАРОЕ РЕШЕНИЕ
          duration_avg += tile.duration;
          //durations_max.increment(tile.duration+"");
          //durations_med = append(durations_med, tile.duration);
        } else if (time == notes[inote].start) {
          tile.addMainNote(notes[inote]);
        } else {
          println("А вы ноту пропустили! :(");
          i++;
        }

      inote++;
    } else { 
      if (time <= misc[imisc].time) {
        time = misc[imisc].time;
        tile.addMisc(misc[imisc]);
        imisc++;
      }
    }
  }
  tiles = (Tile[]) append(tiles, tile);


  tiles[1].need_press = true;

  //Продолжительность максимального количества плиток 
  //durations_max.sortValuesReverse();
  //String[] keys = durations_max.keyArray();
  //int dur = int(keys[0]);

  //Средняя продолжительность 
  float dur = (float)(duration_avg / tiles.length);


  //Медианная продолжительность
  //durations_med = sort(durations_med);
  //int dur = durations_med[durations_med.length/2];

  speed = (float)(((float)height/tiles_in_col)/dur);
  thr_time = (int)(height / speed);


  //Может всё переделать на время вместо пикселей?


  float max_gap = (float) height/tiles_in_col/2;
  float pref_h = (float) height/tiles_in_col;
  float[] space = new float[tiles_in_row];
  int[] ind = new int[tiles_in_row]; //Индекс плитки, занимающей место в определённом столбце
  //Теперь начинается общий случай

  for (int i = 1; i < tiles.length; i++) {
    tiles[i].h = (float)(tiles[i].duration*speed);

    float gap = (float)((tiles[i].start_time - tiles[i - 1].start_time)*speed);
    int[] rolls = new int[]{};

    for (int ii = 0; ii < tiles_in_row; ii++) {
      if (space[ii] >= 0) {
        space[ii] = 0;
        rolls = append(rolls, ii); //Никогда плитки подряд идти не будут
        ind[ii] = -1;
      } else {
        space[ii] += gap; //одну итерацию положительные значения будут присутствовать
      }

      // if ((space[ii] < max_gap && space[ii] > 0)||(space[ii] > -max_gap && space[ii] < 0 && tiles[ind[ii]].h + space[ii] >= pref_h)) { //Увеличение и уменьшение расстояния
      //if (space[ii] < max_gap && space[ii] > 0) { //Увеличение only
      //  tiles[ind[ii]].h += space[ii];
      //  tiles[ind[ii]].y = -tiles[ind[ii]].h;
      //  space[ii] = 0;
      //  ind[ii] = -1;
      //}
    }
    int colomn =0;

    if (rolls.length > 0) {
      colomn = rolls[(int) random(0, rolls.length)];
    }
    tiles[i].col =  colomn;
    space[colomn] -= tiles[i].h;
    ind[colomn] = i;
  }
  return tiles;
}
