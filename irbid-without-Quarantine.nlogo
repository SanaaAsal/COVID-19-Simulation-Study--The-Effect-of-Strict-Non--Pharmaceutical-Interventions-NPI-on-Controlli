; This model is a translation (eventually) of Carolyn Orbann's model of the spread of measles at Mission San Diego. It has been translated by Carolyn Orbann and Lisa Sattenspiel.
; ALL THIS IS HEADING TOWARDS SOME ERROR CHECKING IN REASSIGNMENT WITH THE LARGER POPULATION
extensions [profiler]


;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Variable Declarations;;
;;;;;;;;;;;;;;;;;;;;;;;;;;

globals [
  ;; Slider variables. Baseline values listed below are standard values to use if not exploring the effect of the particular variable. Estimated are derived from the literature. One
  ;; tick = 1 hour, so 1 day = 24 ticks.
  ;; latent-period  ; baseline value = 10 days or 240 ticks (from literature)
  ;; infectious-period  ; baseline value = 6 days or 144 ticks  (from literature)
  ;; transmission-prob ; baseline value = 0.025 per tick, which gives an overall value of 0.9739 for the cumulative transmission probability. This generates an attack rate
  ;;    of over 90%, as indicated in the literature for colonial populations
  ;; death-prob ; baseline value = 0.001996 per tick which converts to about 250 per 1000 deaths over the course of an epidemic, a value estimated from another mission in California
  ;;    during the same epidemic
  ;; run-length ; default value is 3600 ticks or 150 days, sets the number of ticks a simulation should run
  ;; start-tick ; time at which a run will start; M 6-10 am = 1; used to set the timekeeper properly

  pop-size ; This variable is used for data recording purposes only and is set equal to the count of agents at the start of a simulation
  num-susceptible num-exposed num-infectious num-recovered num-dead

  RD ; The sum of recovered and dead. Gives total number of cases.
  SRD ; The sum of susceptible, recovered, and dead. If an epidemic runs through completely, this will equal population size.

  first-case ; the agt-id of the first infected case
  first-case-occ ; the occupation of the first infected case
  peak-number
  peak-tick-list
  peak-tick
  final-tick
  final-tick-recorded?

  monjeria-id ; the building ID of the monjeria, initialized in import-map-data
;;  monjeria-hshld ; the dwelling number corresponding to the monjeria, initialized in import-map-data PROBABLY NOT NEEDED IN SAN DIEGO MODEL
  church-id ; the building ID of church, initialized in import-map-data
  fields-id ; id of the fields building
  kitchen-id ; id of the kitchen building
  num-houses
  num-monjeria
  num-priestQ
  num-kitchens
  num-churches
  num-fields
  num-storage
  num-bldgs
  house-list
  bldg-list

  timekeeper ; determines the simulation's current 1-hour time block so agent's call the appropriate activity methods or record the present time in selected print statements.
             ; Timekeeper values of 1-24 correspond to hours on Mondays through Saturdays (12 am, 1 am, ..., 11 pm). Values of 25-48 correspond
             ; to the same time slots on Sunday.

]

breed [SDagents SDagent]
breed [ghosts ghost]

turtles-own [ ; The first 14 variables are read in from a file
  agt-id ; the simulation id number of a specific agent
  agt-RIN; the record number of the agent in the Ancestral quest geneaology file.
  ;This links to their baptismal, marriage, and burial record numbers, if available
  mission  ; All agents are given a value of 1 which corresponds to Mission San Diego
  father-pat ; father's patriline
  father-mat ; father's matriline
  mother-pat ; mother's patriline
  mother-mat ; mother's matriline
  disease-status ; 0 = susceptible, 1 = exposed, 2 = infectious, 3 = recovered, 4 = dead
  dwelling ; The ID of a person's dwelling
  nuc-family ; The ID of a person's extended family. All agents are currently set to 0 because this variable is designed for future model versions.
  sex ; male = 0, female = 1
  age
  health-history ; Corresponds to an agent's relative health status, designed to take into account different possible influences that may impact an agent's outcome when faced with a potential
  ; disease-transmitting contact. This variable can range from -1 to 1, with -1 corresponding to a maximum negative impact (i.e., 100% reduction), 0 corresponding to no impact on health,
  ; and 1 corresponding to a maximum positive impact. All agents are currently set to 0 because this variable is designed for future model versions.
  occupation ; is a user-defined integer variable corresponding to a agent's occupation. All agents have been assigned a 3-digit occupation code. See the Info tab for more details on these
  ; specific occupation codes. Occupations refer to agent behavior categories that relate to normal daily activities.
  spouse-RIN; the Ancestral Quest Record ID number of an agent's spouse
  spouse-id ; ID of an agent's spouse

  present-location ; building ID of the patch where an agent is located
  original-dwelling; building ID of the original dwelling assigned at the beginning of the simulation. Retained for use when people move to monjeria (mostly)
  can-visit? ; a boolean variable that indicates whether an agent is allowed to visit another agent
  prob-visit; a float variable that indicates the probability that an individual is allowed to visit when calling move-visit. Initialized at 1.0 (always able to visit) and not yet implemented at
  ;other values yet.
  temp-dwelling ; the building of a dwelling to be visited temporarily when space is not available at home

  time-to-infectious ; Timer variable set equivalent to the latent period that starts running at the tick a agent is infected
  time-to-recovery ; Timer variable set equivalent to the infectious period that starts running at the tick an infected agent becomes infectious
  time-infected ; Tick at which the agent is infected
  place-infected ; ID of the location where an agent is infected
  time-died
  place-died
  infector-id ; the agt-id of the infecting agent
  infector-occ ; the occupation of the infecting agent
  infector-dwelling ; the ID of the infecting agent's dwelling
  infector-father-mat ; the father's matriline of the infecting agent
  infector-father-pat ;the father's matriline of the infecting agent
  infector-mother-mat ;the mother's matriline of the infecting agent
  infector-mother-pat ;the mother's patriline of the infecting agent

  newly-infected?
  newly-infectious?; THIS IS NOT IN THE REPAST VERSION OF THE SAN DIEGO MODEL, BUT WE WANT TO KEEP THIS BECAUSE IT IS USEFUL FOR DATA COLLECTION
  newly-dead?
  step-completed?
   ]

SDagents-own [ ; THE TWO VARIABLES IN THIS GROUP ARE USED IN THE NETLOGO MODEL'S TRANSMISSION METHODS. THEY DO NOT APPEAR IN THE SAN DIEGO MODEL, BUT SHOULD IN THE ADAPTATION
  possible-new-cases
  possible-infectors
]

patches-own [
  building-id ; the ID of the building situated on the patch
  building-type ; 1 = house, 2 = monjeria, 3 = school, 4 = hospital, 5 = church, 6,7 = boat
  occupied? ; determines whether a patch is occupied by an agent or not. IN THE REPAST VERSION, THIS WAS CALLED 'OCCUPANCY' AND ALSO WAS A BOOLEAN VARIABLE
]

;;;;;;;;;;;;;;;;;
;;Setup Methods;;
;;;;;;;;;;;;;;;;;

to profile
  setup
  profiler:start
  repeat 600 [ go ]
  profiler:stop
  print profiler:report
  profiler:reset
end

to setup
  clear-all
  ask patches [
    set pcolor gray + 4
    set occupied? false
    set building-id 0]
  import-map-data
  import-agent-data
  initialize-globals
  infect-first-case
  create-files
  reset-ticks
end

; This procedure creates the buildings on the San Diego map by reading in a file that contains the coordinates of the lower left hand corner for each building, the dimensions, building ID and building type.
; Each building ID is added to a building list after its data are read in and the count for that respective building type is incremented. A list of houses is also made. The method then identifies
; the remaining cells in the building and ensures that they have the same building ID, type, and color as the input cell. Those patches that are not buildings retain the base gray color.
to import-map-data
  set house-list []
  set bldg-list []
  file-open "SDbldgs.txt" ; NEED FILE FOR SAN DIEGO MODEL
  while [not file-at-end?]
  [
    ; The following code reads a single line into a six-item list and uses the information in the list to create the buildings
    let items read-from-string (word "[" file-read-line "]") ; Items is a temporary list of variables read in as string but converted to the appropriate variable type.
                                                             ; "Word" concatenates the brackets to the line being read in, because list arguments need to be in brackets
                                                             ; (see Netlogo user manual)
    let llc-x item 0 items
    let llc-y item 1 items
    let building-width item 2 items
    let building-length item 3 items

    ask patch llc-x llc-y [
      set building-id item 4 items
      set building-type item 5 items
      set bldg-list lput building-id bldg-list

      if building-type = 1
         [
           set num-houses num-houses + 1
           set pcolor cyan
           set house-list lput building-id house-list
           set num-bldgs num-bldgs + 1
         ] ; houses

      if building-type = 2
      [
        set num-monjeria num-monjeria + 1
        set pcolor orange + 1
        set num-bldgs num-bldgs + 1
        ] ; monjeria

      if building-type = 3
      [
        set num-priestQ num-priestQ + 1
        set pcolor red + 2
        set num-bldgs num-bldgs + 1
        ] ; priest quarters

      if building-type = 4
      [
        set num-kitchens num-kitchens + 1
        set pcolor turquoise + 1
        set num-bldgs num-bldgs + 1
        ] ; kitchen

      if building-type = 5
      [
        set num-churches num-churches + 1
        set pcolor violet + 3
        set num-bldgs num-bldgs + 1
        ] ; church

      if building-type = 6
      [
        set num-fields num-fields + 1
        set pcolor green
        set num-bldgs num-bldgs + 1
        ] ; fields

      if building-type = 7
      [
        set num-fields num-storage + 1
        set pcolor sky
        set num-bldgs num-bldgs + 1
        ] ; storage area
      ]
    ; the following block finds all patches in a building and sets their id, type, and color to match that assigned to the lower left hand corner patch
    let building-patches (patch-set patches with [pxcor >= llc-x and pxcor < (llc-x + building-width) and pycor >= llc-y and pycor < (llc-y + building-length)])
    ask building-patches [
      set building-id [building-id] of patch llc-x llc-y
      set building-type [building-type] of patch llc-x llc-y
      set pcolor [pcolor] of patch llc-x llc-y
    ]
  ] ; closes while
  file-close

  set monjeria-id 171
  set church-id 175
  set fields-id 176
  set kitchen-id 172

end

; This procedure creates the agents and assigns their attributes by reading in a file that contains the 14 agent-specific attributes listed above as turtles-own variables
; and indicated as input from file. It also sets the initial values of the additional turtles-own variables that are not read in.
to import-agent-data
  file-open "SDfullpop.txt"
  ; The following code reads in all the data in the file. Each line of data contains the values for the first 14 attributes for a single agent in the order listed below.
  while [not file-at-end?]
  [
    let items read-from-string (word "[" file-read-line "]") ; Items is a temporary list of variables read in as string but converted to the appropriate variable type. "Word" concatenates
    ; the brackets to the line being read in, because list arguments need to be in brackets (see Netlogo user manual)
    create-SDagents 1 [
      set agt-id item 0 items
      set agt-RIN item 1 items
      set mission item 2 items
      set father-pat item 3 items
      set father-mat item 4 items
      set mother-pat item 5 items
      set mother-mat item 6 items
      set disease-status item 7 items
      set dwelling item 8 items
      set nuc-family item 9 items
      set sex item 10 items
      set age item 11 items
      set health-history item 12 items
      set occupation item 13 items
      set spouse-RIN item 14 items

      set present-location 0
      set original-dwelling dwelling
      set can-visit? true
      set prob-visit 1.0

      set time-to-infectious latent-period
      set time-to-recovery infectious-period
      set time-infected -1
      set place-infected -1
      set time-died -1
      set place-died -1
      set infector-id -1
      set infector-occ -1
      set infector-father-mat -1
      set infector-father-pat -1
      set infector-mother-mat -1
      set infector-mother-pat -1
      set infector-dwelling -1

      set newly-infected? false
      set newly-infectious? false
      set newly-dead? false
      set step-completed? false

      set shape "circle"

      ifelse (occupation = 800)
      [set color magenta - 1]
      [set color black]

      set size 1
    ]
  ]
  file-close

  ask turtles
  [
    initialize-home

  ]
end

to initialize-home
  let spouse nobody
  let spouses []
  set spouses (turtle-set SDAgents with [agt-RIN = [spouse-RIN] of myself])
  ;print count spouse
  ifelse (count spouses > 1)
  [type "agent " type agt-id print " has more than one spouse, check data"]
  [if (count spouses = 1)
    [ set spouse one-of spouses
        set spouse-id [agt-id] of spouse
 ; type "agent " type agt-id type " has set agent " type spouse-id print " as their spouse"
    ]
  ]



  let home-patches (patch-set patches with [building-id = [dwelling] of myself and not occupied?])
  ifelse any? home-patches
  [
     let dest-patch one-of home-patches
     assign-location (dest-patch)
  ] ; closes "if"
  [ ; no unoccupied patches in assigned dwelling
   print "There is no room in the assigned house for the agent. Check house assignments in data file to ensure that the number of assigned agents is no larger than the size of the house."
  ] ; close else
end

to initialize-globals
  set pop-size count SDagents
  set num-susceptible count SDagents
  set num-exposed 0
  set num-infectious 0
  set num-recovered 0
  set num-dead 0
  set RD 0
  set SRD 0

  set first-case 0
  set first-case-occ 0
  ;; The following five variable are new to the Netlogo version because we didn't know how to collect this data in RePast and were collecting it
  ;; were collecting it in Excel
  set peak-number -1
  set peak-tick-list []
  set peak-tick -1
  set final-tick -1
  set final-tick-recorded? false

  set timekeeper 0
end

to infect-first-case ; This method should be used when the epidemic starts at time 0. If a user wants to delay the start of the epidemic, the call for infect-first-case will need
                     ; to be moved out of the setup procedure and the time infected will need to be reset to the delayed time after the method is called (because the method sets the
                     ; time infected to 0).
  ;ask one-of SDagents with [occupation != 800][  ; Randomly chooses one SDagent, other than the priest, to be the first case.
  ask turtles with [agt-id = 30 or agt-id = 33] [ ; Chooses a specific SDagent to be the first case. If a random agent with specific characteristics is desired, the code can be changed accordingly. NOTE: when using
   ; "ask turtle," the agent must be identified by its who value, which is the agt-id - 1
    set disease-status 1 ; "Exposed"
    set num-exposed 1
    set num-susceptible num-susceptible - 1
    set color yellow + 2
    set time-to-infectious latent-period

    ; The indicated values for the following variables allow the user to easily identify the first case in output data
    set time-infected 0
    set place-infected [building-id] of patch-here
    set infector-id 0
    set infector-occ 0
    set infector-dwelling 0
    set first-case agt-id
    set first-case-occ occupation
    type "Agent " type agt-id print " is the first case."
  ;  ask other turtles with [dwelling = [dwelling ] of myself and color != yellow + 2] [ set color pink ] ; other members of the first cases's household
   ]

end


;;;;;;;;;;;;;;;;
;;Step Methods;;
;;;;;;;;;;;;;;;;

to go
    ask turtles [  ; the newly? variables reset here are for data recording purposes and to prevent multiple transmissions (e.g. if an agent is infected by another before it goes through the
    ; go method itself and before disease variables are updated accordingly).
    if time-infected != ticks + 1 [
    set newly-infected? false
  ]
  set newly-dead? false
  ]

  ask one-of turtles [set-timekeeper]

  ask SDagents [
    if (disease-status = 1 or disease-status = 2) [
    update-disease-status
    ]

  if disease-status != 4 [

  find-days-activities

  ; The following code only causes actions if there are any infectious agents. In that case it first makes a turtle set of the 4 von Neumann neighbors of the calling agent. If that
  ; agent is susceptible, then the method makes a subset of the neighbor-agents turtle set that consists of neighbors who are infectious. The method transmit-from is then called to
  ; determine whether the calling agent becomes infected. If the calling agent is already infectious, then a subset of susceptible neighbors is made and the transmit-to method determines
  ; whether any of those neighbors become infected. We are assuming a Von Neumann neighborhood (N, S, E, W neighbors only) rather than a Moore Neighborhood because the Moore neighborhood,
  ; with its eight neighbors (adds NE, SE, SW, NW), causes disease transmission to be unrealistically rapid. In thinking about the process, it seems that a limit of four contacts at a time
  ; reflects how many individuals people interact with simultaneously, even in relatively crowded situations.

  let neighbor-agents (turtle-set SDagents-on neighbors4)
  ifelse disease-status = 0
     [
       if any? neighbor-agents with [disease-status = 2]
     [
      set possible-infectors neighbor-agents with [disease-status = 2]
      transmit-from (possible-infectors)
     ] ; closes if any?
     ] ; closes if of disease-status = 0
     [ ; opens else of disease-status = 0
       if disease-status = 2
       [
         if any? neighbor-agents with [disease-status = 0]
         [
         set possible-new-cases neighbor-agents with [disease-status = 0]
         transmit-to (possible-new-cases)
         ] ; closes if any? neighbor-agents
       ] ; closes if disease-status = 2
     ] ; closes else of disease-status = 0
  ] ; closes if disease-status != 4
    if newly-dead? [death-aftermath]
    set step-completed? true
  ] ; closes ask SDagents


;  ask ghosts with [newly-dead?] [
;    death-aftermath]  ; Immediately after SDagents die, any caretakers must arrange for dependent children to be reassigned to new caretakers.

  ; The next few lines of code reset boolean variables for the next iteration of the go method.

  ask turtles [
    set step-completed? false
    set newly-infectious? false
    set prob-visit 1.0 ;if we change movement prob due to illness, will need to add code here or elsewhere? maybe use an if statement for suscept and recovered folks.
    ]
;if (remainder (ticks + 1) 24 = 0) [ ;this will collect data for each *day* only, starting at time 0
  update-daily-output
 ; ]
  ; The tick value (on a slider on the interface) can and should be set with the appropriate parameter value to make sure that the entire epidemic is included in data output.
  if ticks + 1 = run-length [
    update-final-output
    stop]

  ; type "This is the end of step " print ticks + 1
  tick
end

; The program is set up for hourly time ticks, ie. 24 ticks per day. The following series of statements sets up the time schedule within which agent activities will occur.
; Values of timekeeper between 1 and 24 correspond to hourly time intervals on Mondays through Saturdays (in this order); values of timekeeper between 25 and 48 correspond hourly
; intervals on Sundays.

to set-timekeeper
  let counter ticks + start-tick
  if (remainder (counter - 1) 24 = 0) and (remainder (counter - 145) 168 != 0) [set timekeeper 1]
    if (remainder (counter - 2) 24 = 0) and (remainder (counter - 146) 168 != 0) [set timekeeper 2]
      if (remainder (counter - 3) 24 = 0) and (remainder (counter - 147) 168 != 0) [set timekeeper 3]
        if (remainder (counter - 4) 24 = 0) and (remainder (counter - 148) 168 != 0) [set timekeeper 4]
          if (remainder (counter - 5) 24 = 0) and (remainder (counter - 149) 168 != 0) [set timekeeper 5]
            if (remainder (counter - 6) 24 = 0) and (remainder (counter - 150) 168 != 0) [set timekeeper 6]
              if (remainder (counter - 7) 24 = 0) and (remainder (counter - 151) 168 != 0) [set timekeeper 7]
                if (remainder (counter - 8) 24 = 0) and (remainder (counter - 152) 168 != 0) [set timekeeper 8]
                  if (remainder (counter - 9) 24 = 0) and (remainder (counter - 153) 168 != 0) [set timekeeper 9]
                    if (remainder (counter - 10) 24 = 0) and (remainder (counter - 154) 168 != 0) [set timekeeper 10]
                      if (remainder (counter - 11) 24 = 0) and (remainder (counter - 155) 168 != 0) [set timekeeper 11]
                        if (remainder (counter - 12) 24 = 0) and (remainder (counter - 156) 168 != 0) [set timekeeper 12]
                          if (remainder (counter - 13) 24 = 0) and (remainder (counter - 157) 168 != 0) [set timekeeper 13]
                            if (remainder (counter - 14) 24 = 0) and (remainder (counter - 158) 168 != 0) [set timekeeper 14]
                              if (remainder (counter - 15) 24 = 0) and (remainder (counter - 159) 168 != 0) [set timekeeper 15]
                                if (remainder (counter - 16) 24 = 0) and (remainder (counter - 160) 168 != 0) [set timekeeper 16]
                                  if (remainder (counter - 17) 24 = 0) and (remainder (counter - 161) 168 != 0) [set timekeeper 17]
                                    if (remainder (counter - 18) 24 = 0) and (remainder (counter - 162) 168 != 0) [set timekeeper 18]
                                      if (remainder (counter - 19) 24 = 0) and (remainder (counter - 163) 168 != 0) [set timekeeper 19]
                                        if (remainder (counter - 20) 24 = 0) and (remainder (counter - 164) 168 != 0) [set timekeeper 20]
                                          if (remainder (counter - 21) 24 = 0) and (remainder (counter - 165) 168 != 0) [set timekeeper 21]
                                            if (remainder (counter - 22) 24 = 0) and (remainder (counter - 166) 168 != 0) [set timekeeper 22]
                                              if (remainder (counter - 23) 24 = 0) and (remainder (counter - 167) 168 != 0) [set timekeeper 23]
                                                if (remainder (counter - 24) 24 = 0) and (remainder (counter - 168) 168 != 0) [set timekeeper 24]
                                                  if (remainder (counter - 145) 168 = 0) [set timekeeper 25]
                                                    if (remainder (counter - 146) 168 = 0) [set timekeeper 26]
                                                      if (remainder (counter - 147) 168 = 0) [set timekeeper 27]
                                                        if (remainder (counter - 148) 168 = 0) [set timekeeper 28]
                                                          if (remainder (counter - 149) 168 = 0) [set timekeeper 29]
                                                            if (remainder (counter - 150) 168 = 0) [set timekeeper 30]
                                                              if (remainder (counter - 151) 168 = 0) [set timekeeper 31]
                                                                if (remainder (counter - 152) 168 = 0) [set timekeeper 32]
                                                                  if (remainder (counter - 153) 168 = 0) [set timekeeper 33]
                                                                    if (remainder (counter - 154) 168 = 0) [set timekeeper 34]
                                                                      if (remainder (counter - 155) 168 = 0) [set timekeeper 35]
                                                                        if (remainder (counter - 156) 168 = 0) [set timekeeper 36]
                                                                          if (remainder (counter - 157) 168 = 0) [set timekeeper 37]
                                                                            if (remainder (counter - 158) 168 = 0) [set timekeeper 38]
                                                                              if (remainder (counter - 159) 168 = 0) [set timekeeper 39]
                                                                                if (remainder (counter - 160) 168 = 0) [set timekeeper 40]
                                                                                  if (remainder (counter - 161) 168 = 0) [set timekeeper 41]
                                                                                    if (remainder (counter - 162) 168 = 0) [set timekeeper 42]
                                                                                      if (remainder (counter - 163) 168 = 0) [set timekeeper 43]
                                                                                        if (remainder (counter - 164) 168 = 0) [set timekeeper 44]
                                                                                          if (remainder (counter - 165) 168 = 0) [set timekeeper 45]
                                                                                            if (remainder (counter - 166) 168 = 0) [set timekeeper 46]
                                                                                              if (remainder (counter - 167) 168 = 0) [set timekeeper 47]
                                                                                                if (remainder (counter - 168) 168 = 0) [set timekeeper 48]
end

to find-days-activities ; timekeeper values of 1-6, 23-30, and 47-48 correspond to sleeping times when nothing happens (timekeeper 1-6 equals 12-5am on Monday through Saturday
  ; timekeeper 23-24 is 10-11pm on Monday through Saturday, timekeeper 25-30 equals 12-5am on Sunday, and timekeeper 47-48 equals 10-11pm Sunday. Because nothing happens at these times
  ; the find-days-activities does not need to include them. Time begins at midnight (i.e. timekeeper = 1 is 12 o'clock am).

  if ((timekeeper = 7) or (timekeeper = 31)) [do-6am-Acts]
  if ((timekeeper = 8) or (timekeeper = 32)) [do-7am-Acts]
  if ((timekeeper = 9) or (timekeeper = 33)) [do-8am-Acts]
  if ((timekeeper = 10) or (timekeeper = 11))[do-MSat910am23pm-Acts]
  if (timekeeper = 12) [do-MSat11am4pm-Acts]
  if ((timekeeper = 13) or (timekeeper = 37)) [do-Noon-Acts]
  if (timekeeper = 14) [do-MSat1pm-Acts]
  if ((timekeeper = 15) or  (timekeeper = 16))[do-MSat910am23pm-Acts]
  if (timekeeper = 17) [do-MSat11am4pm-Acts]
  if ((timekeeper = 18) or (timekeeper = 42)) [do-5pm-Acts]
  if ((timekeeper = 19) or (timekeeper = 43)) [do-6pm-Acts]
  if ((timekeeper = 20) or (timekeeper = 44)) [do-7pm-Acts]
  if ((timekeeper = 21) or (timekeeper = 45)) [do-8pm-Acts]
  if ((timekeeper = 22) or (timekeeper = 46)) [do-9pm-Acts]
  if ((timekeeper = 34) or (timekeeper = 35))[do-Sun910am-Acts]
  if (timekeeper = 36) [do-Sun11am-Acts]
  if (timekeeper = 38) [do-Sun1pm-Acts]
  if (timekeeper = 39) [do-Sun2pm-Acts]
  if (timekeeper = 40) [do-Sun3pm-Acts]
  if (timekeeper = 41) [do-Sun4pm-Acts]

end

; See info tab for details on the timing of different activities and descriptions of each occupation (occupation type).

to do-6am-Acts
 if (occupation = 500) ;boys go to help out in the kitchen. All others should be at home
  ;[ move-to-bldg (kitchen-id) ]
  [ move-home ]

end

to do-7am-Acts ;everyone moves within their dwelling (or back to the household)
  move-home
end

to do-8am-Acts ;everyone goes to church
 if (ticks < 10 ) and (ticks < 15)
  [move-to-bldg (church-id)]
end

to do-MSat910am23pm-Acts
  let boy-cutoff 0
  let boy-prob 0

 if ((occupation = 100) or (occupation = 300)) ;adult men (aingle and married) move to fields
  [move-to-bldg (fields-id)]

 if ((occupation = 200) or (occupation = 600)) ; married/over 45 women and young girl children weave around the neighborhoods (inside and outside of houses)
  [move-weave
  ]

 if (occupation = 400) ; monjeria ladies stay in the monjeria
  [move-home ]

 if (occupation = 500) ; boy children, chance of going to work in the kitchen or the fields. As they get older, the chance of field work increases and kitchen work decreases
 [set boy-cutoff (age * 0.08) - 0.22
  set boy-prob random-float 1.0
   if (boy-prob < boy-cutoff)
    [move-to-bldg (fields-id)]
   ; [move-to-bldg (kitchen-id)]
  ]

  if (occupation = 700) ; babies/toddlers moving in a house area. They can move independently from their mothers here because they are in the same general area as their mothers and supervised from afar.
   [ifelse (dwelling != monjeria-id) ;babies/toddlers living with mothers in the monjeria move within that building
      [move-weave
      ]
      [move-home]
  ]

  ;if (occupation = 800) ;priest gets to go where ever he wants. He is checking up on everyone throughout the day
  ; [
  ; let priest-choice one-of (bldg-list)
  ; move-to-bldg (priest-choice)
 ; ]

end

to do-Sun910am-Acts ;Everyone goes to church, required
 ; move-to-bldg (church-id)

end

to do-MSat11am4pm-Acts ;nearly the same as do-MSat910am23pm-Acts, except boys must move to the kitchen at this time to help with meal prep
 if ((occupation = 100) or (occupation = 300))
  [move-to-bldg (fields-id)]

 if ((occupation = 200) or (occupation = 600))
  [move-weave
  ]

 if (occupation = 400)
  [move-home ]

 ;if (occupation = 500)
    ; [move-to-bldg (kitchen-id)]

  if (occupation = 700)
   [ifelse (dwelling != monjeria-id)
      [move-weave
      ]
      [move-home]
  ]

  ;if (occupation = 800)
  ; [
  ;  let priest-choice one-of (bldg-list)
  ; move-to-bldg (priest-choice)
  ;]

end

to do-Sun11am-Acts ;boys go to kitchen, everyone else stays at church
  ;if (occupation = 500)
    ; [move-to-bldg (kitchen-id)]
    ; [move-to-bldg (church-id)]
end

to do-noon-Acts ;everyone goes to their designated dwelling for midday meal
    move-home
end

to do-MSat1pm-Acts ; All school-aged children and the priest go to the church building for catechism, everyone else moves within their dwelling
 if ((occupation = 500) or (occupation = 600) or (occupation = 800))
 ; [move-to-bldg (church-id)]
  [move-home]
end

to do-Sun1pm-Acts ;everyone moves within their
 move-home
end

to do-Sun2pm-Acts ; one adult from each household decides whether visiting will occur. If so, all household members go with that agent.
if (occupation <= 400 )
  [if (can-visit? and (random-float 1.0 <= prob-visit))
    [ move-visit ]
  ]

;if (occupation = 800) ;priest does whatever he wants
 ;  [
; let priest-choice one-of (bldg-list)
 ;  move-to-bldg (priest-choice)
 ; ]
end

to do-Sun3pm-Acts
; ifelse (occupation = 800) ;priest does whatever he wants, everyone else stays where they are to continue visiting, (or not!), moving within the building they are currently in.
 ;  [
 ;let priest-choice one-of (bldg-list)
 ;  move-to-bldg (priest-choice)
 ; ]
 ; [move-to-bldg (present-location)]
end

to do-Sun4pm-Acts ;like Sun3pm-Acts, except that boys go to the kitchen
; ifelse ((occupation != 800) and (occupation != 500))
 ;   [move-to-bldg (present-location)]
 ; [
 ;   if (occupation = 800)
 ;   [let priest-choice one-of (bldg-list)
  ;    move-to-bldg (priest-choice)]
   ; [ifelse (occupation = 500)
    ;  [move-to-bldg (kitchen-id)]
     ; [type "agent occupation type " type occupation print " is trying to move to the kitchen on Sunday at 4pm"]
       ;   ]
 ; ]
end

to do-5pm-Acts ;everyone goes home
   move-home
   set can-visit? true
end

to do-6pm-Acts ; Families can visit again, but women in monjerias and their children and the priest stay in their dwellings
 if (occupation <= 300)
  [ifelse (can-visit? and (random-float 1.0 <= prob-visit))
    [ move-visit ]
    [move-to-bldg (present-location)
    ]
  ]

  if ((occupation = 400) or (occupation = 800))
  [move-home]

end

to do-7pm-Acts ; same at do-6pm-Acts
 if (occupation <= 300)
  [ifelse (can-visit? and (random-float 1.0 <= prob-visit))
    [ move-visit ]
    [move-to-bldg (present-location)
    ]
  ]

 if ((occupation = 400) or (occupation = 800))
   [move-home]
end

to do-8pm-Acts ; families continue visiting, monjeria and priests don't move inside their buildings here, assumption is that they are sleeping (limits possible transmission)
 if (occupation <= 300)
   [ifelse (can-visit? and (random-float 1.0 <= prob-visit))
    [ move-visit ]
      [ move-to-bldg (present-location)
      ]
  ]
 ;left priest out here. No reason for him to move inside his own house
end

to do-9pm-Acts ;Families all go home for the night.
ifelse ((occupation = 400) or (occupation = 800))
  [];if you are a priest or monjeria girl, do nothing
  [move-home];everyone else move home

  set can-visit? true
end


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Destination-related movement methods;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to move-home

  ; The moveHome method moves agents to or within their assigned dwellings at any time after model initialization. If an agent attempts
  ; to move within a full house, it stays where it is. If the house is full when an agent tries to return from outside, it picks a different
  ; dwelling to go to, but is not reassigned permanently.

  let group-size 1
  ; In the present model, only individuals call move-home, so group-size is set at 1.  If in the future we have groups traveling home, we need
  ; to set group-size equal to the size of the traveling group.

  let dest-patch patch-here ; initialized at the agent's present location

  let home-patches (patch-set patches with [building-id = [dwelling] of myself and not occupied?])
  ifelse any? home-patches
  [
     set dest-patch one-of home-patches
  ] ; closes "if"
  [
    ; no unoccupied patches in assigned dwelling. If already at home, do nothing; if not at home, find a dwelling to visit
    ; if dwelling is the monjeria and the monjeria is full, find new dwelling to visit

    ifelse (present-location != dwelling) [
       set temp-dwelling find-visit-dwelling (group-size)
       let visit-dest-patches (patch-set patches with [building-id = [temp-dwelling] of myself and not occupied?])
       set dest-patch one-of visit-dest-patches
  ]
    [ ;Print "Neither agent's dwelling nor any other dwellings are available. Agent doesn't move"
    ]
  ] ; close else
  assign-location (dest-patch)
end

to move-to-bldg [bldg-ID]
  ; The move-to-Bldg method sends agents to the building that is indicated by the building ID that is indicated when the method is called.
  ; If no space is available, the agent the agent stays where they were, resetting their destination patch to be their current location.

  let dest-patch patch-here
  let bldg-patches (patch-set patches with [building-id = [bldg-ID] of myself and not occupied?])
    if any? bldg-patches
    [
     set dest-patch one-of bldg-patches ;if nothing is available, in the chosen building dest-patch does not change and agent remains at previous location.
    ] ; closes if

  assign-location (dest-patch)
end

to move-weave
; The move-weave method allow women and their babies/toddlers to pick a target patch within their dwelling but then look at a set of patches within a radius of 2 of that patch. This set of patches may
; include outside patches adjacent to a building, which allows weaving to occur outside and potentially allows for mixing of women women who live near each other.

  let weave-patches no-patches
  let dest-patch patch-here
  let dwell-patches (patch-set patches with [building-id = [dwelling] of myself])
  let target-patch one-of dwell-patches
    ;ask target-patch [let weave-patches patch-set (patches in-radius 2 with [not occupied?]);;add patch-here and to make the patch set properly, then winnow down the patch-set based on occupancy and building id
   ; ask target-patch [let weave-patches patches in-radius 2 with [not any? turtles-here]]
  ask target-patch [set weave-patches neighbors with [not any? turtles-here]]
  set weave-patches (patch-set weave-patches target-patch)
  ; ask myself [
    ifelse any? weave-patches
      [  set dest-patch one-of weave-patches with [((building-id = 0) or (building-id = [dwelling] of myself))]  ]
      [  set dest-patch patch-here  ]
   ; ]
  assign-location (dest-patch)
end

to move-visit
let visit-building-id dwelling
let occupants nobody
ifelse dwelling = monjeria-id
  [set occupants (turtle-set self) ] ;;exclude monjeria girls from dragging their roomies with them
  [set occupants (turtle-set SDagents-on patches with [building-id = [present-location] of myself])]
set visit-building-id find-visit-dwelling (count occupants)
 ; type "2. visit-building-id " print visit-building-id
move-group occupants visit-building-id
end


;;;;;;;;;;;;;;;;;;;;;;;;
;;Movement sub-methods;;
;;;;;;;;;;;;;;;;;;;;;;;;

;; Procedure for finding a dwelling to visit. Not used for permanent reassignment. Checks for space available in a synchronous fashion
to-report find-visit-dwelling [group-num] ; reports the dwelling a family will visit, not used for permanent reassignment. Only needs to make sure there are spaces
                                          ; available at the time the space is checked
  let available-cells 0
  let visit-house-list []
  set visit-house-list house-list
  set visit-house-list remove dwelling visit-house-list
  let visit-dwelling-id one-of visit-house-list
  let visit-dwelling-found? false

  set available-cells count patches with [building-id = visit-dwelling-id and not occupied?]

;  type "Dwelling " type visit-dwelling-id type " has been chosen as the visit dwelling. Available-cells = " print available-cells

  while [(not empty? visit-house-list) and (visit-dwelling-found? = false)]
  [
    ifelse ((available-cells >= group-num) and (available-cells != count patches with [building-id = visit-dwelling-id]))
   [ ; the agent has found a visit-dwelling, but needs to make sure there are relatives in the building
      let hosts (turtle-set SDagents-on patches with [building-id = visit-dwelling-id])
      ask hosts [
         if (visit-dwelling-found? = false)
        [
             if ((father-pat = [father-pat] of self)) ; or (mother-pat = [mother-pat] of self))  COMMENTED OUT TO TEST THE POPULATION WITH JUST PATRILINEAL ORGANIZATION
             [ask self [set visit-dwelling-found? true]]
  ]
  ]
      ]
   [
      set visit-house-list remove visit-dwelling-id visit-house-list
         if (empty? visit-house-list)
        [
        set visit-dwelling-id dwelling
        set visit-dwelling-found? true
;        type "Agent " type agt-id type " could not find a visit dwelling and is staying home at dwelling " print visit-dwelling-id
      ]
    ]
    if visit-dwelling-found? = false
    [
      set visit-house-list remove visit-dwelling-id visit-house-list
         ifelse (not empty? visit-house-list)
        [
        set visit-dwelling-id one-of visit-house-list
        set available-cells count patches with [building-id = visit-dwelling-id and not occupied?]
      ]
      [
        set visit-dwelling-id dwelling
        set visit-dwelling-found? true
;        type "Agent " type agt-id type " could not find a visit dwelling and is staying home at dwelling " print visit-dwelling-id
      ]
  ]
  ]
    report visit-dwelling-id
end


to-report find-kin-house [group-num] ; reports a kin house for use in reassignment. We don't use this for visiting purpose because it checks for residents,
  ;regardless of if they are actually in the building at the time of the residency check.
  let available-cells 0
  let kin-house-list []
  set kin-house-list house-list
  set kin-house-list remove dwelling kin-house-list
  let kin-house-id one-of kin-house-list
  let kin-house-found? false
  let kin-house-res nobody

  while [(not empty? kin-house-list) and (kin-house-found? = false)]
 [set kin-house-res (turtle-set SDagents with [dwelling = kin-house-id])
  set available-cells count patches with [building-id = kin-house-id] - count kin-house-res ;should be the total number of available spaces in a house, even if residents aren't currently home
  ifelse (available-cells >= group-num) ;checking to see if there is eventually room for the group to move in
      [;comparing patrilines
          ask kin-house-res with [age > 12]
          [;only going to try to kin match adults in the household. We were trying to avoid any problems with matching reassigned children.
         if (kin-house-found? = false)
        [if ((father-pat = [father-pat] of self)) ;; or (mother-pat = [mother-pat] of self)) commented out to test the population with just a patrilineal organization
        [; print "I have found a patriline match"
        ask self [set kin-house-found? true]
            ]
        ]
        ]
        ];close if
    [ set kin-house-list remove kin-house-id kin-house-list
      if (empty? kin-house-list)
     [; print "I am not able to find a kin house, so I am staying home"
        set kin-house-id dwelling
        set kin-house-found? true
      ]
    ];close else

    if (kin-house-found? = false)
    [set kin-house-list remove kin-house-id kin-house-list
      ;type length kin-house-list print " spots to choose from. My first choice of kin-dwelling was bad, so I'm trying again."
     ifelse (not empty? kin-house-list)
      [ set kin-house-id one-of kin-house-list
        set kin-house-res (turtle-set SDagents with [dwelling = kin-house-id])
        set available-cells count patches with [building-id = kin-house-id] - count kin-house-res
      ]
      [set kin-house-id dwelling
       set kin-house-found? true
    ]
    ]
    ]
;  type "1. Kin-house-id " print kin-house-id
  report kin-house-id

end

to assign-location [destination] ; this method is only called when "destination" (a specific patch) is known to be available at a desired building.
  if destination = nobody [type agt-id print destination ]
  ask patch-here [
    set occupied? false]
  setxy [pxcor] of destination [pycor] of destination
  set present-location [building-id] of patch-here
  ask patch-here [set occupied? true]
end

; move-group contains code to allow a group to visit another place. This is called by any agent directing its own movement or that of a group it is responsible for. The ID of the
; building to be visited and the traveling group are determined by the appropriate agent before the method is called. During this process, the calling agent also makes sure that
; there is enough space in the visit-bldg for the entire group. The group then moves to the building chosen.

to move-group [group-set visit-bldg]
  ask group-set [
  let visit-patches (patch-set patches with [building-id = visit-bldg and not occupied?]) ; each agent in the group-set makes their own set of unoccupied visit-patches
  let dest-patch nobody
  ifelse count visit-patches = 0 ; This might occur if the group is staying home. In that situation there would be enough space available, but if the house is full, there would
                                 ; be no unoccupied cells. In this case, the dest-patch would be assigned to the present location.
  [set dest-patch patch-here]
  [set dest-patch one-of visit-patches]
  assign-location (dest-patch)

  ]

  ; The following makes sure that can-visit becomes false when a group either goes to visit someone else or is being visited.

      if ([building-type] of patch-here = 1) [
        let occupant-set (turtle-set SDagents-on patches with [building-id = visit-bldg])
           ask occupant-set [
           set can-visit? false
    ]
  ]
end

;;;;;;;;;;;;;;;;;;;
;;Disease Methods;;
;;;;;;;;;;;;;;;;;;;

to update-disease-status ; An SDagents method called near the beginning of the go method. Depending on their current disease status and the value of relevant timing variables,
  ; SDagents will transition to the next disease status or reduce the time remaining for the current status (or die, with some probability, if they are infectious). The durations of disease
  ; stages are equal for all SDagents.
  let adjusted-death-prob 0
  ; Susceptible SDagents do nothing

  ; Exposed agents must check the value of time-to-infectious to see if they should become infectious this time period.
  if disease-status = 1
  [
    ifelse time-to-infectious = 0
       [set disease-status 2
        set newly-infectious? true
        set time-to-recovery infectious-period
        set color red]
       [set time-to-infectious time-to-infectious - 1]
    ] ; closes if of disease-status = 1

;  [ ; opens else of disease-status = 1

  ; Infectious agents first check whether they will die this time period. If they survive, they must check the value of time-to-recovery to see if they should recover this time period.
  if disease-status = 2  [
    if not newly-infectious? [
    let death-threshold random-float 1.0
      ifelse (age >= 15) [set adjusted-death-prob death-prob * 1.25] ;gives adults a higher prob of death as it is written. Can also be used to give older folks less chance of dying
      [set adjusted-death-prob death-prob]
    if death-threshold <= adjusted-death-prob
      [create-ghost]
    ]

    ifelse time-to-recovery = 0 and disease-status = 2 ; The ifelse statement includes the disease-status component so agent who die this tick don't override changes made in create-ghost
       [set disease-status 3
        set color violet - 1]
       [set time-to-recovery time-to-recovery - 1]
  ] ; closes if disease-status = 2
;  ] ; closes else of disease-status = 1

  ; Recovered and dead SDagents do nothing.

end

; transmit-to and transmit-from assign a random probability of transmission to a contact between an infectious and a susceptible agent. When such a contact occurs, the method compares the
; parameter value of the transmission probability to the assigned probability. If the transmission probability is greater than or equal to the assigned probability, then disease transmission
; occurs and the susceptible agent moves into the exposed state. The length of time in the exposed class is determined by the parameter latent-period. If the transmission probability is less
; than the assigned probability, the susceptible agent does not change disease status. NOTE: AT THE PRESENT TIME THE LENGTH OF THE LATENT PERIOD IS ASSUMED TO BE CONSTANT.

to transmit-from [infectors-set] ; called by a susceptible agent
  let susc-agent self
  let prob random-float 1.0
  ask infectors-set [
    if (disease-status = 2 and prob <= transmission-prob  and not [newly-infected?] of susc-agent) ; the condition "disease-status = 2" is not really needed since it is used in making the infector's set,
                                                                                   ; but it reminds us here that that is the case
    [
      if ((building-id = [building-id] of susc-agent) or (building-type = 0 and [building-type] of susc-agent = 0)) [
        ; transmission is possible only if the agents are in the same building or they are both outside (women during Move-weave)(the infectors set is already limited to neighbors)
      ask susc-agent [
        set disease-status 1
        set color yellow
        set time-to-infectious latent-period - 1 ; the subtraction of 1 from the latent period takes the present time tick into account
        set time-infected ticks + 1  ; The plus one is to correct the timing since ticks increment at the end of the go method and thus it is recording the previous value of ticks
        ; during the current go.
        set place-infected [building-id] of patch-here
        set infector-id [agt-id] of myself ; myself now refers to the member of infectors-set who called the above "ask susc-agent".
        set infector-occ [occupation] of myself
        set infector-dwelling [dwelling] of myself
        set infector-father-mat [father-mat] of myself
        set infector-father-pat [father-pat] of myself
        set infector-mother-mat [mother-mat] of myself
        set infector-mother-pat [mother-pat] of myself
        set newly-infected? true
        ] ; closes ask susc-agent
      ] ; closes if ((building-id ...)
      ] ; closes if (disease-status ...)
    ] ; closes ask infectors-set
end

to transmit-to [new-cases-set] ; called by an infectious agent
  let infector-agent self
  let prob random-float 1.0
  ask new-cases-set [
    if (disease-status = 0 and prob <= transmission-prob) [ ; the condition "disease-status = 0" is not really needed since it is used in making the new-cases-set, but it reminds us here that that is the case
      if ((building-id = [building-id] of infector-agent) or (building-type = 0 and [building-type] of infector-agent = 0)) [
      set disease-status 1
      set color yellow
      set time-to-infectious latent-period ; time-to-infectious is set to the latent period here (not latent period - 1) because the new case is not the agent calling the method. If the new
                                           ; case has already completed its step, its time-to-infectious is adjusted at the end of this method. Otherwise, that adjustment occurs in update-disease-status
                                           ; when that agent completes its step.
      set time-infected ticks + 1  ; The plus one is to correct the timing since ticks increment at the end of the go method and thus it is recording the previous value of ticks
                                   ; during the current go.
      set place-infected [building-id] of patch-here
      set infector-id [agt-id] of infector-agent
      set infector-occ [occupation] of infector-agent
      set infector-dwelling [dwelling] of infector-agent
      set infector-father-mat [father-mat] of infector-agent
      set infector-father-pat [father-pat] of infector-agent
      set infector-mother-mat [mother-mat] of infector-agent
      set infector-mother-pat [mother-pat] of infector-agent
      set newly-infected? true
      if step-completed? [
        set time-to-infectious time-to-infectious - 1
      ]
      ]
    ]
  ]
  end

;;;;;;;;;;;;;;;;;
;;Death Methods;;
;;;;;;;;;;;;;;;;;

; The create-ghost method is called by an SDagent who has died. It records death-related variables and creates a new turtle
; in the breed "ghost" with the same attributes as the calling agent. The calling agent is then moved to the cemetery (coordinates 1,1)
; and the GhostAgent remains at the location where the agent died. Users can control whether the ghost is visible or not with the
; "hide-turtle" statement below.

to create-ghost
  type "agent " type  agt-id print " has died"
  set shape "ghost"
  set disease-status 4
  set color gray
  set newly-dead? true
  set time-died ticks + 1 ; as in the transmission methods above, the plus one needs to correct for how the go method keeps track of time
  set place-died [building-id] of patch-here
  hatch-ghosts 1 [
  set shape "ghost"
  set color white
  set size 2
  ask patch-here
  [set occupied? false]
  hide-turtle ;This can be commented out if user wants to see the ghosts on the landscape
  ]

  ; The following statements set the size of ghosts in the cemetery to be proportional to the number of ghosts in order to provide a
  ; visualization of the number of deaths during the epidemic. At present this code results in multiple visible ghosts of different
  ; sizes superimposed on one another at the location of the cemetery. The icons are also centered over the patch (1,1), with the
  ; result that when the ghost gets large enough, only part of it can be seen. These are commented out for batch runs, but need to
  ; be uncommented for gui runs.
  setxy 1 1
  ;  let prop-ghosts (count ghosts / pop-size)
  ;  if prop-ghosts > 0.01  [set size floor (prop-ghosts * 50)]
end

; The death-aftermath method is called by all newly dead agents.
to death-aftermath
  let dying-agent self
  let spouse-age 0
  let new-home 0
  let old-home 0
  set old-home dwelling
  let surviving-spouse nobody
  ; The live-children is set for the purpose of determining new caretakers for children of a dying agent who is a primary caretaker.
  ; Therefore the set only needs to contain children who are assigned to the same dwelling as the dying agent.
    let live-children (turtle-set SDagents with [disease-status != 4 and (occupation >= 500 and occupation < 800) and dwelling = [dwelling] of dying-agent])
  ;This set includes all girls and young boys who move with mothers to the monjeria when their father dies or mover together to a kin house or the monjeria when their mother dies
    let stay-with-mom-group (turtle-set live-children with [sex = 1 or age < 4] )

  ;The Live adults set does not include monjeria girls because they cannot be caregivers
  let live-adults (turtle-set SDagents with [disease-status != 4 and (occupation >= 100 and occupation < 400)])
;  let surviving-spouses SDagents with [agt-id = [spouse-id] of dying-agent]
  let surviving-spouses (turtle-set SDagents with [agt-id = [spouse-id] of myself])
  if count surviving-spouses = 1
  [  set surviving-spouse one-of surviving-spouses
     set spouse-age [age] of surviving-spouse]
 if count surviving-spouses > 1 [type "This agent " type agt-id print " more than one spouse. Check data."]
end
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;Data Collection and Display Update Methods;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

to update-daily-output
  tally
  record-ticks
  draw-plots
  write-to-daily-file
end

to tally
  set num-susceptible count SDagents with [disease-status = 0]
  set num-exposed count SDagents with [disease-status = 1]
  set num-infectious count SDagents with [disease-status = 2]
  set num-recovered count SDagents with [disease-status = 3]
  set num-dead count ghosts
  set RD num-recovered + num-dead ; size of epidemic
  set SRD num-susceptible + RD ; should equal total population size if the epidemic concluded by the time the simulation ended
end

to record-ticks
  let current-tick ticks + 1
  ifelse num-infectious > peak-number
    [set peak-number num-infectious
     set peak-tick-list [] ; clears list
     set peak-tick-list (list current-tick)] ; since only 1 number added here, (list ...) is needed to declare the variable type
    [if num-infectious = peak-number [set peak-tick-list lput current-tick peak-tick-list]]

  if SRD = pop-size and not final-tick-recorded? [
    set final-tick ticks ; the epidemic ended the previous tick, so the tick correction is not applied here
    set final-tick-recorded? true
  ]
end

to draw-plots
  set-current-plot "Course of epidemic"
  ;set-current-plot-pen "susceptibles"
  ;plot num-susceptible
  set-current-plot-pen "exposed"
  plot num-exposed
  set-current-plot-pen "infectious"
  plot num-infectious
  set-current-plot-pen "recovered"
  plot num-recovered
  set-current-plot-pen "dead"
  plot num-dead
end

to create-files
  ; The following four lines can be called before creating a data file so that if that file has been used before, it gets erased before adding data for a new run. See Railsback & Grimm (2012)
  ; for examples.
;  if (file-exists? "SanDiego-casesData.csv")[
;    carefully
;      [file-delete "SanDiego-casesData.csv"]
;      [print error-message]]

  ; The next three blocks of code put headers at the top of new output files (one each for case, daily and final data) and then the files are closed again, which must happen before a
  ; simulation begins. The process of inserting headers only happens if the files don't exist already. If a file does exist, output data are just appended to data from previous simulations
  ; without inserting headers again.

;  if (not file-exists? "SanDiego-cases.csv")[
;  file-open "SanDiego-cases.csv"
;  file-type "Population Size, "
;  file-type "Transmission Probability, "
;  file-type "Mortality Probability, "
;  file-type "Latent Period, "
;  file-type "Infectious Period, "
;  file-type "First Case ID, "
;  file-print "First Case Occ, "
;  file-type (word pop-size ", ")
;  file-type (word transmission-prob ", ")
;  file-type (word death-prob ", ")
;  file-type (word latent-period ", ")
;  file-type (word infectious-period ", ")
;  file-type (word first-case ", ")
;  file-print (word first-case-occ ", ")
;  file-type "Run Number,"
;  file-type "Tick, "
;  file-type "Agent ID, "
;  file-type "Agent Dwelling, "
;  file-type "Agent Occupation, "
;  file-type "Agent Father Pat, "
;  file-type "Agent Father Mat, "
;  file-type "Agent Mother Pat, "
;  file-type "Agent Mother Mat, "
;  file-type "Infector ID, "
;  file-type "Infector Dwelling, "
;  file-type "Infector Occupation, "
;  file-type "Infector Father Pat, "
;  file-type "Infector Father Mat, "
;  file-type "Infector Mother Pat, "
;  file-type "Infector Mother Mat, "
;  file-type "Time Infected, "
;  file-type "Place Infected, "
;  file-type "Time Died, "
;  file-type "Place Died, "
;  file-print "Start Tick, "
;  file-close]

  if (not file-exists? "SanDiego-DailyRep.csv")[
  file-open "SanDiego-DailyRep.csv"
  file-type "Run Number,"
  file-type "Tick, "
  file-type "Population Size, "
  file-type "Transmission Probability, "
  file-type "Mortality Probability, "
  file-type "Latent Period, "
  file-type "Infectious Period, "
  file-type "First Case ID, "
  file-type "First Case Occ, "
  file-type "Susceptible, "
  file-type "Newly Infected, "
  file-type "Exposed, "
  file-type "Infectious, "
  file-type "Recovered, "
  file-type "Newly Dead, "
  file-type "Total Dead, "
  file-print "Start Tick, "
  file-close]

  if (not file-exists? "SanDiego-FinalRep.csv")[
  file-open "SanDiego-FinalRep.csv"
  file-type "Run Number,"
  file-type "Tick, "
  file-type "Population Size, "
  file-type "Transmission Probability, "
  file-type "Mortality Probability, "
  file-type "Latent Period, "
  file-type "Infectious Period, "
  file-type "First Case ID, "
  file-type "First Case Occ, "
  file-type "Peak Size, "
  file-type "Peak Tick List, "
  file-type "Peak Tick, "
  file-type "Final Tick, "
  file-type "Susceptible, "
  file-type "Recovered, "
  file-type "Total Dead, "
  file-type "R+D (Number of cases), "
  file-type "S+R+D (Finish?), "
  file-print "Start Tick, "
  file-close]

end


to write-to-daily-file
  file-open "SanDiego-DailyRep.csv"
  file-type (word behaviorspace-run-number ", ")
  file-type (word (ticks + 1) ", ") ; The Netlogo clock starts at tick 0. One tick is added in data recording
                                    ; so that model events start at time 1 instead of time 0. For example, the
                                    ; first tick that the initial case is infectious is latent period + 1, i.e. tick 7
                                    ; if the latent period is 6 days. This also ensures that the data recording is
                                    ; consistent with the visualization.
  file-type (word pop-size ", ")
  file-type (word transmission-prob ", ")
  file-type (word death-prob ", ")
  file-type (word latent-period ", ")
  file-type (word infectious-period ", ")
  file-type (word first-case ", ")
  file-type (word first-case-occ ", ")
  file-type (word num-susceptible ", ")
  file-type (word count SDagents with [newly-infected?] ", ")
  file-type (word num-exposed ", ")
  file-type (word num-infectious ", ")
  file-type (word num-recovered ", ")
  file-type (word count ghosts with [newly-dead?] ", ")
  file-type (word num-dead ", ")
  file-print (word start-tick ", ")
  file-close
end

to update-final-output
  let earliest-peak min peak-tick-list
  let latest-peak max peak-tick-list
  set peak-tick (earliest-peak + latest-peak) / 2 ; Note: may think about averaging the entire list
 ; write-to-cases-file ;un-comment this line to make the cases data file
  write-to-final-file
end

to write-to-cases-file
  file-open "SanDiego-Cases.csv"
  foreach sort-on [agt-id] SDagents [ [?1] ->
  ask ?1 [

  file-type (word behaviorspace-run-number ", ")
  file-type (word (ticks + 1) ", ")
  file-type (word agt-id ", ")
  file-type (word dwelling ", ")
  file-type (word occupation ", ")
  file-type (word father-pat ", ")
  file-type (word father-mat ", ")
  file-type (word mother-pat ", ")
  file-type (word mother-mat ", ")
  file-type (word infector-id ", ")
  file-type (word infector-dwelling ", ")
  file-type (word infector-occ ", ")
  file-type (word infector-father-pat ", ")
  file-type (word infector-father-mat ", ")
  file-type (word infector-mother-pat ", ")
  file-type (word infector-mother-mat ", ")
  file-type (word time-infected ", ")
  file-type (word place-infected ", ")
  file-type (word time-died ", ")
  file-type (word place-died ", ")
  file-print (word start-tick ", ")
  ]
  ]
  file-close
end

to write-to-final-file
  file-open "SanDiego-FinalRep.csv"
  file-type (word behaviorspace-run-number ", ")
  file-type (word (ticks + 1) ", ") ; See comment above in the write-to-daily-file method.
  file-type (word pop-size ", ")
  file-type (word transmission-prob ", ")
  file-type (word death-prob ", ")
  file-type (word latent-period ", ")
  file-type (word infectious-period ", ")
  file-type (word first-case ", ")
  file-type (word first-case-occ ", ")
  file-type (word peak-number ", ")
  file-type (word peak-tick-list ", ")
  file-type (word peak-tick ", ")
  file-type (word final-tick ", ")
  file-type (word num-susceptible ", ")
  file-type (word num-recovered ", ")
  file-type (word num-dead ", ")
  file-type (word RD ", ")
  file-type (word SRD ", ")
  file-print (word start-tick ", ")
  file-close
end
@#$#@#$#@
GRAPHICS-WINDOW
260
10
672
423
-1
-1
2.68
1
10
1
1
1
0
0
0
1
0
150
0
150
1
1
1
ticks
30.0

BUTTON
25
88
91
121
NIL
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
108
90
171
123
step
go
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
191
90
254
123
run
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
53
141
226
174
latent-period
latent-period
0
480
40.0
40
1
ticks
HORIZONTAL

SLIDER
53
190
226
223
infectious-period
infectious-period
0
400
320.0
2
1
ticks
HORIZONTAL

SLIDER
53
239
226
272
transmission-prob
transmission-prob
0
1
0.25
0.001
1
NIL
HORIZONTAL

SLIDER
53
288
226
321
death-prob
death-prob
0
0.05
0.001996
0.000001
1
NIL
HORIZONTAL

PLOT
795
10
1318
283
Course of epidemic
tick
number of agents
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"exposed" 1.0 0 -1184463 true "" ""
"infectious" 1.0 0 -2674135 true "" ""
"recovered" 1.0 0 -13791810 true "" ""
"dead" 1.0 0 -11053225 true "" ""

SLIDER
54
333
226
366
run-length
run-length
0
880
880.0
40
1
ticks
HORIZONTAL

BUTTON
90
46
162
79
NIL
profile
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
53
376
225
409
start-tick
start-tick
1
168
1.0
1
1
NIL
HORIZONTAL

MONITOR
699
71
785
116
Exposed
count turtles with [disease-status = 1]
17
1
11

MONITOR
699
123
786
168
Infectious
count turtles with [disease-status = 2]
17
1
11

MONITOR
698
19
785
64
Susceptible
count turtles with [disease-status = 0]
17
1
11

MONITOR
699
175
786
220
Recovered
count turtles with [disease-status = 3]
17
1
11

MONITOR
699
227
787
272
Dead
count turtles with [disease-status = 4]
17
1
11

@#$#@#$#@
# Netlogo version of SanDiego model

Version date: Feb 2018

Authors: Carolyn Orbann and Lisa Sattenspiel,

SAMort model provided the stimulus for many of the structures and methods used in this model.


## INTRODUCTION

The SanDiego model is an epidemiological model designed to test hypotheses related to the spread of the 1805 measles epidemic among indigenous residents of Mission San Diego during the early mission period in Alta California. The model community is based on the population of the Mission San Diego community, as listed in the parish documents (baptismal, marriage, and death records). Model agents are placed on a map-like grid that consists of houses, the mission church, a women's dormitory (monjeria) adjacent to the church, a communal kitchen, priest's quarters, and agricultural fields. They engage in daily activities that reflect known ethnographic patterns of behavior at the mission. A pathogen is introduced into the community and then it spreads throughout the population as a consequence of individual agent movements and interactions.


## MODEL INITIALIZATION

During the set-up procedure, the agent and map variable files are read in, the community layout and visualization are established, data output files are created, and variables for recording epidemic data are initialized. The first case (or cases, if desired) are selected. Users may decide whether to select a first case at random or according to certain criteria (e.g. an agent of a particular sex, age or occupation type).


## EXTERNAL INPUT FILES

The model requires the use of two external input files, one to read in essential agent characteristics, and one to read in building characteristics. To facilitate explorations of the impact of population size on epidemic outcomes, we have made a number of different agent files and associated building files corresponding to target population sizes. In making different sized agent populations, households are kept together. Each larger population includes all agents from the smaller population files, with newly added households chosen randomly from among remaining households included in the full population until the target population size is reached. Because agents can repeatedly attempt to visit empty houses in small population runs, we eliminated from the building files all houses without any assigned agents. We always assume that one priest lives in the community. He ministers to the entire population. This priest is also assumed to be permanently and totally immune to measles, as a consequence of childhood exposure.

### AGENT CHARACTERISTICS

Agent definition files (SanDiegoAgents100.txt and other similar files for different population sizes) include the following variables:

1. The first column of this file is the user-determined agent ID.

2. The second column of this file is the Record Identification Number (RIN) corresponding
to the real person's entry in the geneology program file (ancestral quest). This RIN allows connection to the baptismal, marriage, and death record from the San Diego.

3. Column 3 is the id number of the mission. San Diego is designated as 1, and is the only mission in the data at this time.

4. Column 4 is a user generated father's patriline id (theoretical only, may be connected to a known clan names in the future).

5. Column 5 is a user generated father's matriline id (theoretical only, may be connected to a known clan names in the future).

6. Column 6 is a user generated mother's patriline id (theoretical only, may be connected to a known clan names in the future).

7. Column 7 is a user generated mother's matriline id (theoretical only, may be connected to a known clan names in the future).

8. Column 8 is an agent's disease status. Currently this variable is initialized at zero for all agents; the program picks an initial infected or exposed agent (or agents) and resets its disease status whenever appropriate, given the agent's infection state. (0=susceptible, 1=exposed, 2=infected, 3=recovered, 4=dead).

9. Column 9 is the dwelling of an agent. This is the agent's home base. The assigned numbers correspond to particular buildings on the model space. For example, individuals assigned to dwelling #35 will use building #35 as their home unless no spaces are available, in which case the program reassigns a new permanent dwelling. Dwellings may change depending on epidemic-related events (deaths in the household, for example)

10. Column 10 designates nuclear family membership.  The variable allows connections between closely related individuals, such as siblings. Currently not being used, all set at 0.

11. Column 11 indicates sex of an agent (0 = male, 1 = female). The assigned sex corresponds to information inferred from baptismal and marriage data.

12. Column 12 designates an agent's age in years.

13. Column 13 corresponds to an agent's relative health status. This variable is designed to take into account different possible influences that may impact an agent's outcome when faced with a potential disease-transmitting contact. At present, this variable can range from -1 to 1, with -1 corresponding to a maximum negative impact (i.e., 100% reduction), 0 corresponding to no impact on health, and 1 corresponding to a maximum positive impact. In the current input data files, health-history is set at 0 for all agents because this is something that will be incorporated into the model later.

14. Column 14 designates an agent's occupation.  This variable is user-defined and influences the activity patterns of agents. All agents have been assigned a 3-digit occupation code.  The assignment rubric is described in the section on  occupation categories.

15. Column 15 designates the ID of the agent's spouse. Spouse information information comes from the San Diego parish marriage and baptismal records. All unmarried agents are given a spouse ID of 0.


### BUILDING CHARACTERISTICS

The present model has seven building types that we have designed to reflect important places at Mission San Diego, our study community: houses, a monjeria (women's dorm), priest quarters, a kitchen, a church, agricultural fields, and an unused storage area. The number of buildings of each type is calculated by the program as the community map is initialized. Building definition files (SDbldgs100.txt and other similar files for different population sizes) include the following variables:

1. Columns 1 and 2 give the coordinates of the lower left hand cell of a building (x-coordinate, then y-coordinate).

2. Columns 3 and 4 give the dimensions of the building (width, then length).

3. Column 5 is the building ID, assigned by the user.

4. Column 6 designates the building type (house=1, monjeria=2, priest quarter=3, kitchen=4, church=5, agricultural fields= 6, storage area = 7).

## ESSENTIAL PARAMETERS

The model consists of a number of sliders that can be used to adjust the values of essential parameters. At the present time all parameters are set at constant values. Eventually some parameters other than run length and population size may be modeled using a probability distribution rather than constant values. The slider variables include the following:

1. Length of latent period: This is the number of time ticks that an agent remains in the exposed category. The slider is set up to range from 0 to 480 ticks (0 to 20 days in the present model). A reasonable baseline value of 240 ticks (10 days) was derived from an assessment of various values published in the measles literature (e.g. Kim-Farley 1993).

2. Length of infectious period: This is the number of time ticks that an agent remains infectious. This slider is also set up to range from 0 to 288 ticks (0 to 12 days in the present model). A baseline value of 144 ticks (6 days) was derived from an assessment of various values published in the measles literature (e.g.Kim-Farley 1993).

3. Transmission probability: This slider is set up to range between 0 and 1 and corresponds to the probability of transmission when a contact occurs between susceptible and infectious agents. A baseline value of 0.025 per contact was chosen to achieve an estimated transmission probability of at least 90%, as is suggested by published accounts of measles transmission in unvaccinated populations (Aaby et al 1983; Shanks et al 2011; and Wolfe 1982).

4. Probability of death: This slider also ranges from 0 to 1 and corresponds to the probability of death per tick. Death can only occur in the model during the infectious period. The baseline estimate of the death probability was derived by setting the  case fatality rate (cfr) equal to (1- (1 - d)^i), where d is equal to the probability of death per tick and i is the length of the infectious period in ticks. The quantity (1-d)^i gives the overall probability of NOT dying throughout the period of risk. When this value is subtracted from 1 it gives the cfr (overall probability that an infected individual dies at some time during the infectious period). The equation is then solved for d to give the desired probability of dying PER TICK. Multiple studies indicate extreme mortality during the 1805/06 epidemic in California (Cook 1976 and Milliken 1995), as high as 25% of the entire mission population at some northern missions. Since this epidemic is assumed to be a virgin soil epidemic, it is reasonable to assume that everyone was or could be infected, which means generates a cfr of 0.25. For an infectious period of 144 ticks (6 days), 1 - (1 - d)^144 = 0.25. The solution to this equation gives a per tick probability of death of 0.001996. NOTE: the model at present assumes that an agent is at risk of dying only when it is infectious and that the risk is equal for each tick it is infectious.

5. Run length: This is the number of time ticks the simulation will be run.

6. Start tick: This slider allows one to start the epidemic on a specified day. The simulation starts at midnight (12am) on Monday morning.

##OCCUPATION CATEGORIES

All occupations have been assigned a 3-digit number that is a multiple of 100.  The first digit corresponds to the general type of occupation. The model at present does not separate agents within specific occupational classes, but we retain the 3-digit code to allow this to happen later. The overall classification is as follows:

100 -- married men age 13 and over. These agents work in the fields all day Monday through Saturday. The agents are distinguished from single men because when they die, there are special considerations for their wives, all female children, and preschool aged male children.

200 -- married women age 11 and over and widows age 45 and older. These agents spend their occupational time Mon-Sat daytime weaving and doing other household activities in the vicinity of their house. While weaving, they can be either inside or outside, but will only range a maximum of 2 cells from the boundary of their house.

300 -- single men age 13 and over. These agents work in the fields all day Monday through Saturday. They are not parents and generally live with their own parents or other patrilineal relatives rather than in their own households.

400 -- single women ages 11 to 45. All, including widows under age 45, are required to live in the monjeria. They spend all their time there except for church and optional Sunday afternoon visits to relatives' houses.

500 -- male children (age 4-12). The primary responsibility of these agents is to go to the kitchen and bring back the food for each household meal. They can also hang out with other boys at the kitchen (which acts as a proxy social center) at other times of the day. They go to the church one hour each day for catechism, and they may go out to the fields in the afternoon to help older males, with the probability of that activity increasing as they get older.

600 -- female children (age 4-10). Girls also go to catechism one hour a day. Outside of that, they stay with their mothers and do what they do.

700 -- infants (age 0-3). Stay with their mothers and do what they do. During the day Mon-Sat, when mothers and infants are at home, all agents move within the house ± 2 cells. The infants are allowed to be outside when the mothers are inside and vice versa (under the assumption that they may be napping on a bed or under a tree and that other children or neighbors are also around to help keep an eye on them).

800 -- priests. Priests do all church services and conduct the catechism. Outside of these times during the day, they visit random locations in the community, including the fields and the storeroom. The assumption is that because they are responsible for the entire community, they may need to check up on places even if other agents aren't there. During the evening times that the other agents are visiting each other, the priests are in their quarters alone. This is their time to prepare lessons, paperwork, sermons, letters, etc. and to pursue their own religious devotions.



## STEP-DEPENDENT PROCEDURES

The general structure of the go procedure follows. The information in quotes at the end of each component gives the section in which more information can be found.

1. Variables that indicate that infection or death occurred during the previous time step are reset so that these events happening during the present time step are tallied properly.
2. A randomly chosen turtle determines the daily time block corresponding to the current tick of the model ("schedule");
3. SDagents that are exposed or infectious update their disease status ("disease-related procedures");
4. all living SAagents engage in appropriate activities determined by their occ-type and the specific time block corresponding to the current tick of the model ("schedule" and "movement-related procedures");
5. the SAagents with appropriate disease statuses determine to or from whom they might transmit the disease ("disease-related procedures");
6. newly dead ghosts reassign any dependents to new caretakers or the monjeria as appropriate ("death-related procedures");
7. data output files and interface plots are updated ("display and output procedures").


###SCHEDULE

The program is set up for 24 time ticks per day with each time tick 1 hour long. A series of statements using the variable 'timekeeper' sets up a schedule within which agent activities will occur, with the week starting on Monday at 1am. Values of timekeeper between 1 and 24 correspond to successive hours on Mondays through Saturdays; values of timekeeper between 25 and 48 correspond to Sunday time slots.

The findDaysActivities method sends an agent to the proper activities for the specific time tick indicated by the timekeeper variable (and designated by the specific do…acts method for that time tick). Although there are 24 time slots per day, there are no do...acts methods for timekeeper = 1-6 (1am-6am Monday through Saturday), 23-24 (11pm-12am Monday through Saturday), 25-30 (1am-6am Sunday), and 47-48 (11pm Sunday -12am Monnday) because these are times when agents are assumed to be sleeping.


###MOVEMENT-RELATED PROCEDURES

The model contains a specific "do…acts" method for each of the time slots other than 11pm-6am daily (when agents are assumed to sleep). These methods specify particular behaviors for agents based on their occupation. All of which, involve some type of move method. The model contains 4 basic move methods: move-home, move-weave, move-visit, and move-to-bldg. **Move-home** is called whenever an agent either stays at home from one time slot to the next (in which case, they move to another available location within their dwelling) or returns home after spending the previous time slot elsewhere. **Move-weave** is called by any females that do not live the in monjeria and the infants and toddlers being cared for by those females. The method has agents find spots inside or nearby their dwellings to simulate the domestic activities of women Mission San Diego. **Move-visit** governs the movement of families when they visit other households during designated visiting times. The method calls two sub-methods: _find-visit-dwelling_, which identifies a location to visit that is the home of other members of the family's lineage, currently occupied, and has enough space for the entire family, and _move-group_, which ensures that all family members do move to the chosen visit location. The fourth move method, **Move-to-bld** is a general method that requires the input of a specific building's id and ensures that the calling agent moves to that building. This is used to send agents to the kitchen, church, and to the fields and it is also used by the priest, who can move to any location on the space.


###DISEASE RELATED PROCEDURES

The underlying disease transmission model in this simulation is an SEIR epidemic process. All agents begin the simulation in the susceptible state, and then the status of one randomly chosen agent is set to "exposed". The specification of multiple initial infected individuals or specific types of initial cases can be made through simple adjustments of the "infect-first-case" method. Consistent with the SEIR epidemic process, exposed agents convert to the infectious state after a user-specified latent period, which they remain in until recovery (after a user-specified infectious period) or death (which occurs with a user-specified probability during each tick of the infectious period). Immunity is permanent upon recovery. The "update-disease-status" method governs this series of transitions.

Disease transmission can occur between susceptible-infectious pairs of agents that are adjacent to each other on the grid. Agents are considered to be adjacent if they are von Neumann neighbors, i.e., those to the north, south, east, or west. When an agent moves it checks its own disease status as well as that of its neighbors. If a moving agent is susceptible, it calls the method "transmit-from" for all infectious neighbors; if it is infectious, it calls "transmit-to" for all susceptibles. In both cases, transmission itself is determined by comparing the user-specified transmission probability to a randomly chosen number between 0 and 1. If transmission occurs, the status of the susceptible agent(s) is set to "exposed" and the clock for the disease process begins.


###DEATH DEPENDENT PROCEDURES

Death of an agent -- agents have a set probability of dying at each tick of the infectious period. Upon death, a ghost (a different turtle breed) with the same agent characteristics as the dying agent is made and data about where and when the agent died are collected. The agents move to a "cemetery" (lower left-hand corner of the grid); the ghosts remain at the location of death. Users can control whether the ghosts are visible or hidden. Each dying agent also takes the shape of a ghost, with the option to make the size proportional to the number of agents that have died. In this case, the ghost that appears in the cemetery gets larger as the epidemic progresses.

Consequences for survivors after an agent's death -- what happens to surviving family members after an agent's death depends on the characteristics of the dying agent (eg sex, age, marital status), as well as the age and sex of the survivors. 

1. The dying agent is a married male -- if his widow is of reproductive age, she, their small children of either sex, and all of their older daughters move to the monjeria. Older sons stay in the house if any other adults are present (eg a women over age 45, or adult brother). If no adults are present, they try to find a kin house. If that is not available, they just stay in the house for the duration of the epidemic. 
2. The dying agent is an unmarried male -- If he is not a caretaker, no changes are made upon his death. If he is a caretake, the only possible children in the house are males who then try to find a kin house to move to. If that is not available, they stay alone in the house. 
3. The dying agent is an unmarried female -- If she over age 45, she has to make the same decisions as an unmarried male (ie. what happens depends on whether she is sharing her house with children). If she is under age 45, she should be living in the monjeria and her death does not require any changes in residence of others. 
4. The dying agent is a married woman -- If she is already widowed (possible because we don't change the occupation number of a widowed female), she is treated like an unmarried female. If the dying agent is not widowed, then the consequences depend on whether she has children and their age and sex. With the procedures set up to guarantee that children end up in a kin house if possible and if not possible, small children and all daughters go to the monjeria. 
5. The dying agent is a child of any occupation -- nothing needs to be done. No other agents are reassigned when children die 
6. The dying agent is a priests -- ERROR! Priests are assumed to be immune to measles and don't have a chance of death in this simulation.

###DISPLAY AND OUTPUT PROCEDURES

As the simulation proceeds, a graph showing the numbers of susceptible, exposed, infectious, recovered, and dead agents is created and updated each tick. In addition, three csv (comma-delimited) output files are produced (SanDiego-cases.txt, SanDiego-daily.txt, and SanDiego-Final.txt). In each file, run numbers, global parameters (e.g. transmission probability), and attributes of the first case are always recorded. The “Cases” file also records, for all individuals in the model population, the place and time the individual was infected (the default value of -1 is recorded if the individual escapes the simulated epidemic), and if applicable, the place and time it died as well as characteristics of the agent that infected this individual. It also includes parents matriline and patrline information for both the infector and infected agents.  The “Daily” file records the number of individuals in each disease status at each tick of the simulation and keeps track of the number of agents that are newly infected and newly dead. The “Final” file records the total number of individuals in each disease status at the end of the simulation, the total number of individuals ever infected [RD], and a count to verify all members of the model community were either susceptible or removed (recovered or dead) [SRD]. This last count provides an easy way to determine that the simulated epidemic finished in the allotted time; in that case the count will equal the total population size.


## ACKNOWLEDGEMENTS

The code for this model was adapted from a Repast model developed by Lisa Sattenspiel, and Carolyn Orbann at the University of Missouri. The code for reading in the external tab-delimited files that contain building and agent characteristics was modified from code written by Uri Wilensky and submitted to Netlogo's model library. He has waived all copyright and related or neighboring rights to the sample code.
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

ghost
false
0
Polygon -7500403 true true 30 165 13 164 -2 149 0 135 -2 119 0 105 15 75 30 75 58 104 43 119 43 134 58 134 73 134 88 104 73 44 78 14 103 -1 193 -1 223 29 208 89 208 119 238 134 253 119 240 105 238 89 240 75 255 60 270 60 283 74 300 90 298 104 298 119 300 135 285 135 285 150 268 164 238 179 208 164 208 194 238 209 253 224 268 239 268 269 238 299 178 299 148 284 103 269 58 284 43 299 58 269 103 254 148 254 193 254 163 239 118 209 88 179 73 179 58 164
Line -16777216 false 189 253 215 253
Circle -16777216 true false 102 30 30
Polygon -16777216 true false 165 105 135 105 120 120 105 105 135 75 165 75 195 105 180 120
Circle -16777216 true false 160 30 30

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
0
Rectangle -7500403 true true 151 225 180 285
Rectangle -7500403 true true 47 225 75 285
Rectangle -7500403 true true 15 75 210 225
Circle -7500403 true true 135 75 150
Circle -16777216 true false 165 76 116

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -7500403 true true 135 285 195 285 270 90 30 90 105 285
Polygon -7500403 true true 270 90 225 15 180 90
Polygon -7500403 true true 30 90 75 15 120 90
Circle -1 true false 183 138 24
Circle -1 true false 93 138 24

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.1.1
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
<experiments>
  <experiment name="Rep Set" repetitions="100" runMetricsEveryStep="false">
    <setup>setup</setup>
    <go>go</go>
  </experiment>
</experiments>
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
