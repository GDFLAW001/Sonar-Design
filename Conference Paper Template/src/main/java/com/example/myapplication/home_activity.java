package com.example.myapplication;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.view.View;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.ListView;
import android.widget.TextView;
import android.widget.Toast;

import java.util.ArrayList;
import java.util.Map;

public class home_activity extends AppCompatActivity {

    private ListView entries_list;  //list which diary entries get added to
    private Button add_entry_button;
    private int average_NKI;
    private TextView ave_NKI;
    final ArrayList<String> date_NKI = new ArrayList<>();
    final ArrayList<String> dates = new ArrayList<>();
    final String[] months = {"January","Febuary","March","April","May","June","July","August","September","October","November","December"};

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_main);

        SharedPreferences pref = PreferenceManager.getDefaultSharedPreferences(getApplicationContext()); //create sharedPreferences object
        //final SharedPreferences.Editor editor = pref.edit();
        //editor.clear();
        //editor.commit();

        //set up views
        entries_list = findViewById(R.id.categories_list);
        add_entry_button = findViewById(R.id.add_entry_button);
        ave_NKI = findViewById(R.id.ave_nki);

        //go through all entries saved in Sharedprefences and add the dates and NKI values to an array
        Map<String,?> keys = pref.getAll();
        for(Map.Entry<String,?> entry : keys.entrySet()){
            if(entry.getValue()!=null) {
                date_NKI.add(entry.getKey() + "\t\t" + entry.getValue().toString().split("categories")[0].split(",")[2]);
                average_NKI+=Integer.parseInt(entry.getValue().toString().split("categories")[0].split(",")[2]); //add all NKI values to average_NKI, divide by array length later to get average
                dates.add(entry.getKey());
            }
        }

        //divide total NKI value by number of entries to get average
        if(date_NKI.size()!=0) {
            ave_NKI.setText(average_NKI / (date_NKI.size()) + "");
        }

        //if add entry button is clicked, open calculator activity
        add_entry_button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                openCalculator();
            }
        });

        //fill list with entries from sharedPreference
        ArrayAdapter arrayAdapter = new ArrayAdapter(this,android.R.layout.simple_list_item_1, date_NKI);
        entries_list.setAdapter(arrayAdapter);

        //if item in list is pressed, get index of item and call openDiary() with that index, also show Toast message
        entries_list.setOnItemClickListener(new AdapterView.OnItemClickListener() {
            @Override
            public void onItemClick(AdapterView<?> adapterView, View view, int i, long l) {
                Toast.makeText(home_activity.this, date_NKI.get(i).split("/")[0]+" " + months[Integer.parseInt(date_NKI.get(i).split("/")[1].replace("0",""))-1]+" " + date_NKI.get(i).split("/")[2]+"kJ",Toast.LENGTH_SHORT).show();
                openDiary(i);
            }
        });
    }

    public void openCalculator()
    {
        Intent intent = new Intent(this, Calculator_Activity.class);
        startActivity(intent);
    }

    public void openDiary(int index)
    {
        Intent intent = new Intent(this, Diary_activity.class);
        intent.putExtra("date",dates.get(index));                      //get the date corresponding to the array index and start the diary activity with that date
        startActivity(intent);
    }
}
