package com.example.myapplication;

import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.MenuItem;
import androidx.appcompat.app.AppCompatActivity;
import android.preference.PreferenceManager;
import android.view.View;
import android.view.inputmethod.InputMethodManager;
import android.widget.AdapterView;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.ImageButton;
import android.widget.Spinner;
import android.widget.TextView;
import android.widget.Toast;
import java.text.SimpleDateFormat;
import java.util.Calendar;

public class Calculator_Activity extends AppCompatActivity implements AdapterView.OnItemSelectedListener {

    //hides keyboard when background is tapped
    public void hideKeyboard(View view) {
        InputMethodManager inputMethodManager =(InputMethodManager)getSystemService(Calculator_Activity.INPUT_METHOD_SERVICE);
        inputMethodManager.hideSoftInputFromWindow(view.getWindowToken(), 0);
    }

    private int total_meal_kj;    // total kj added from meal input by user
    private int total_burnt_kj;   // total kj added from exercise input by user
    private int NKI_value;        // meal - burnt
    private Calendar calendar;
    private SimpleDateFormat dateFormat;
    private String date;                // current date
    private String meal_categories;     // list of chosen meals
    private String exercise_categories; //list of chosen exercises

    //adds back button on activity bar
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
        setContentView(R.layout.activity_calculator);
        getSupportActionBar().setDisplayHomeAsUpEnabled(true); //enable back button on activity bar

        // create sharedpreferences object
        final SharedPreferences pref = PreferenceManager.getDefaultSharedPreferences(getApplicationContext());
        final SharedPreferences.Editor editor = pref.edit();

        // get the current date
        calendar = Calendar.getInstance();
        dateFormat = new SimpleDateFormat("dd/MM/yyyy");
        date = dateFormat.format(calendar.getTime());

        final EditText meal_text_in = findViewById(R.id.editText);
        final EditText exercise_text_in = findViewById(R.id.editText2);
        final Spinner meal_Spinner = findViewById(R.id.meal_spinner);
        final Spinner exercise_Spinner = findViewById(R.id.exercise_spinner);
        ImageButton home_Button = findViewById(R.id.home_button);
        ImageButton add_Entry_Button = findViewById(R.id.add_entry_button);
        Button add_meal_button = findViewById(R.id.add_meal_button);
        Button add_exercise_button = findViewById(R.id.add_exercise_button);
        final TextView total_consumed = findViewById(R.id.kj_consumed);
        final TextView total_burnt = findViewById(R.id.kj_burnt);
        final TextView NKI = findViewById(R.id.NKI);

        NKI_value = 0;
        total_burnt_kj=0;
        total_meal_kj=0;
        meal_categories="";
        exercise_categories="";

        //if the program rotates or is closed in some way, get saved data and set the relevant textviews.
        if (savedInstanceState != null) {
            NKI_value = savedInstanceState.getInt("NKI_value");;
            total_burnt_kj=savedInstanceState.getInt("total_burnt_kj");;
            total_meal_kj=savedInstanceState.getInt("total_meal_kj");;

            meal_categories=savedInstanceState.getString("meal_categories");
            exercise_categories=savedInstanceState.getString("exercise_categories");

            total_consumed.setText(total_meal_kj+"");
            total_burnt.setText(total_burnt_kj+"");
            NKI.setText(NKI_value+"");
        }

        add_Entry_Button.setOnClickListener(new View.OnClickListener()
        {
            @Override
            public void onClick(View view) {

                if(total_consumed.getText().toString().equalsIgnoreCase("0")&&total_burnt.getText().toString().equalsIgnoreCase("0"))
                {
                    //Toast message if nothing has been entered in the input fields
                    Toast.makeText(Calculator_Activity.this,"Add a meal or exercise first",Toast.LENGTH_SHORT).show();
                }
                else {
                    // if something has already been added to this date, get the already entered data from sharedpreferences and add the new data to that
                    if (pref.contains(date)) {
                        total_meal_kj += Integer.parseInt(pref.getString(date, null).split(",")[0]);
                        total_burnt_kj += Integer.parseInt(pref.getString(date, null).split(",")[1]);
                        NKI_value = total_meal_kj - total_burnt_kj;
                        meal_categories += "-" + pref.getString(date, null).split("categories")[1];
                        exercise_categories += "-" + pref.getString(date, null).split("categories")[2];
                    }

                    //save new data to sharedPreferences with the date as the key. In the form <total meal kJ> , <total exercise categories> , <NKI> categories <mealcategories> categories <exerciseCategories>
                    editor.putString(date, total_meal_kj + "," + total_burnt_kj + "," + NKI_value + "categories" + meal_categories + "categories" + exercise_categories);  // Saving string
                    // commit changes
                    editor.commit();

                    // open the diary activity
                    openDiary(date);
                }
            }

        });

        home_Button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                openMain();
            }
        });

        add_meal_button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                // check that the input isnt empty
                if(!meal_text_in.getText().toString().equalsIgnoreCase("")) {
                    total_meal_kj += Integer.parseInt(meal_text_in.getText().toString());

                    if(!meal_categories.equalsIgnoreCase(""))
                    {
                        meal_categories+="-";
                    }

                    meal_categories += meal_Spinner.getSelectedItem().toString()+": "+meal_text_in.getText().toString()+" kJ";

                    meal_text_in.setText("");
                    total_consumed.setText(total_meal_kj + "");
                    NKI_value = total_meal_kj - total_burnt_kj;
                    NKI.setText(NKI_value + "");


                }
                //toast message if nothing has been entered in input
                else
                {
                    Toast.makeText(Calculator_Activity.this,"Add a meal first",Toast.LENGTH_SHORT).show();
                }
            }
        });

        add_exercise_button.setOnClickListener(new View.OnClickListener() {
            @Override
            public void onClick(View view) {
                if(!exercise_text_in.getText().toString().equalsIgnoreCase("")) {
                    total_burnt_kj += Integer.parseInt(exercise_text_in.getText().toString());

                    if(!exercise_categories.equalsIgnoreCase(""))
                    {
                        exercise_categories+="-";
                    }

                    exercise_categories += exercise_Spinner.getSelectedItem().toString() + ": " + exercise_text_in.getText().toString() + " kJ";

                    exercise_text_in.setText("");
                    total_burnt.setText(total_burnt_kj + "");
                    NKI_value = total_meal_kj - total_burnt_kj;
                    NKI.setText(NKI_value + "");
                }
                else
                {
                    Toast.makeText(Calculator_Activity.this,"Add an exercise first",Toast.LENGTH_SHORT).show();
                }
            }
        });

        meal_Spinner.setOnItemSelectedListener(this);
        exercise_Spinner.setOnItemSelectedListener(this);

        //fill arrays with data located in strings.xml
        ArrayAdapter<CharSequence> adapter = ArrayAdapter.createFromResource(this, R.array.meals, android.R.layout.simple_spinner_item);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        meal_Spinner.setAdapter(adapter);

        adapter = ArrayAdapter.createFromResource(this, R.array.exercises, android.R.layout.simple_spinner_item);
        adapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item);
        exercise_Spinner.setAdapter(adapter);

        //hide keyboards if focus changes to something else
        meal_text_in.setOnFocusChangeListener(new View.OnFocusChangeListener() {
            @Override
            public void onFocusChange(View v, boolean hasFocus) {
                if (!hasFocus) {
                    hideKeyboard(v);
                }
            }
        });

        exercise_text_in.setOnFocusChangeListener(new View.OnFocusChangeListener() {
            @Override
            public void onFocusChange(View v, boolean hasFocus) {
                if (!hasFocus) {
                    hideKeyboard(v);
                }
            }
        });
    }

    @Override
    public void onItemSelected(AdapterView<?> adapterView, View view, int i, long l) {
        if(!adapterView.getItemAtPosition(i).equals("Select a Meal"))
        {
            String item = adapterView.getItemAtPosition(i).toString();
            Toast.makeText(adapterView.getContext(),"Selected: "+ item, Toast.LENGTH_SHORT).show();
        }
    }

    @Override
    public void onNothingSelected(AdapterView<?> adapterView) {
    }

    //save relevant data
    @Override
    public void onSaveInstanceState(Bundle savedInstanceState) {

        savedInstanceState.putInt("NKI_value", NKI_value);
        savedInstanceState.putInt("total_burnt_kj", total_burnt_kj);
        savedInstanceState.putInt("total_meal_kj", total_meal_kj);

        savedInstanceState.putString("meal_categories", meal_categories);
        savedInstanceState.putString("exercise_categories", exercise_categories);

        super.onSaveInstanceState(savedInstanceState);
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
}
