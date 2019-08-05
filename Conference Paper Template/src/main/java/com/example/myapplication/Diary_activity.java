package com.example.myapplication;

import androidx.appcompat.app.AppCompatActivity;

import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.drawable.Drawable;
import android.os.Bundle;
import android.preference.PreferenceManager;
import android.view.MenuItem;
import android.view.View;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.ImageButton;
import android.widget.ListView;
import android.widget.TextView;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Date;
import java.util.Map;

public class Diary_activity extends AppCompatActivity {


    private ListView categories_list;
    private final String[] months = {"January","Febuary","March","April","May","June","July","August","September","October","November","December"};

    @Override
    public boolean onOptionsItemSelected(MenuItem item) {
        switch (item.getItemId()) {
            case android.R.id.home:
                // app icon in action bar clicked; go home
                Intent intent = new Intent(this, home_activity.class);
                intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP);
                startActivity(intent);
                return true;
            default:
                return super.onOptionsItemSelected(item);
        }
    }

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_diary);
        getSupportActionBar().setDisplayHomeAsUpEnabled(true);

        Intent intent = getIntent();
        final String date = intent.getStringExtra("date");
        final SharedPreferences pref = PreferenceManager.getDefaultSharedPreferences(getApplicationContext());

        categories_list = findViewById(R.id.categories_list);
        Button add_entry_button =findViewById(R.id.add_entry_button);
        ImageButton prev_button = findViewById(R.id.decrease_day_button);
        ImageButton next_button = findViewById(R.id.increase_day_button);
        ImageButton home_button = findViewById(R.id.home_button);
        TextView kj_burnt = findViewById(R.id.kj_burnt);
        TextView kj_consumed = findViewById(R.id.kj_consumed);
        TextView NKI = findViewById(R.id.NKI);
        final TextView date_text = findViewById(R.id.date_text);

        //get values from sharedPreference corresponding to date from Intent and set the relevant textFields.
        kj_consumed.setText(pref.getString(date,null).split("categories")[0].split(",")[0]);
        kj_burnt.setText(pref.getString(date,null).split("categories")[0].split(",")[1]);
        NKI.setText(pref.getString(date,null).split("categories")[0].split(",")[2]);
        date_text.setText(date_text.getText()+" "+date.split("/")[0]+" " + months[Integer.parseInt(date.split("/")[1].replace("0",""))-1]+" " + date.split("/")[2]);

        final SimpleDateFormat sdf = new SimpleDateFormat("dd/MM/yyyy");

        //go through all the entries in sharedPreferences, add the ones after the Intent date to one array, and the ones before the Intent date to another array
        final ArrayList<Date> dates_after = new ArrayList<>();
        final ArrayList<Date> dates_before = new ArrayList<>();

        Map<String,?> keys = pref.getAll();
        for(Map.Entry<String,?> entry : keys.entrySet()){
            if(entry.getValue()!=null) {
                try {
                    if(sdf.parse(entry.getKey()).after(sdf.parse(date)))
                    {
                        dates_after.add(sdf.parse(entry.getKey()));
                    }
                    else if(sdf.parse(entry.getKey()).before(sdf.parse(date)))
                    {
                        dates_before.add(sdf.parse(entry.getKey()));
                    }
                } catch (ParseException e) {
                    e.printStackTrace();
                }
            }
        }

        Date closest_day_before=null;
        Date closest_day_after=null;

        if(dates_before.size()!=0) {
            closest_day_before = dates_before.get(0);
        }

        if(dates_after.size()!=0)
        {
            closest_day_after = dates_after.get(0);
        }

        //find the next date after the Intent date and the previous date before the Intent date
        for (int j = 0; j < dates_before.size(); j++) {
            if (dates_before.get(j).after(closest_day_before)) {
                closest_day_before = dates_before.get(j);
            }
        }

        for (int j = 0; j < dates_after.size(); j++) {
            if (dates_after.get(j).before(closest_day_after)) {
                closest_day_after = dates_after.get(j);
            }
        }

        //if the next or previous button is pressed, reopen the diary activity and parse the new date
        final Date finalClosest_day_after = closest_day_after;
        next_button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                openDiary(sdf.format(finalClosest_day_after));
            }
        });

        final Date finalClosest_day_before = closest_day_before;
        prev_button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                openDiary(sdf.format(finalClosest_day_before));
            }
        });

        //if there is no date before or no date after the Intent date, set the next and previous buttons grey and disable them
        Drawable grey_background = getDrawable(R.drawable.rounded_corners_drawable_grey);
        if(dates_after.size()==0)
        {
            next_button.setBackground(grey_background);
            next_button.setEnabled(false);

        }
        if(dates_before.size()==0)
        {
            prev_button.setBackground(grey_background);
            prev_button.setEnabled(false);
        }

        add_entry_button.setOnClickListener(new View.OnClickListener()
        {
            @Override
            public void onClick(View view) {
                openCalculator();
            }

        });

        home_button.setOnClickListener(new View.OnClickListener()
        {
            @Override
            public void onClick(View view) {
                openMain();
            }

        });

        //fill the array with the relevant data from sharedPreferences
        String categories = pref.getString(date,null).split("categories")[1] +"-"+ pref.getString(date,null).split("categories")[2];
        String[] categories_list=categories.split("-");
        for (int i = 0; i < categories_list.length; i++)
        {
            categories_list[i] = String.format("%-25s", categories_list[i].split(":")[0]+":"+categories_list[i].split(":")[1]);
        }
        ArrayAdapter arrayAdapter = new ArrayAdapter(this,android.R.layout.simple_list_item_1, categories_list);
        this.categories_list.setAdapter(arrayAdapter);
    }

    public void openDiary(String date)
    {
        Intent intent = new Intent(this, Diary_activity.class);
        intent.putExtra("date",date);
        startActivity(intent);
    }

    public void openMain()
    {
        Intent intent = new Intent(this, home_activity.class);
        startActivity(intent);
    }

    public void openCalculator()
    {
        Intent intent = new Intent(this, Calculator_Activity.class);
        startActivity(intent);
    }
}
