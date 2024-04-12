----------------------------------------------------------------------
--       Title:07.14.01.01 - Crew Change - Import flight details - Segments
-- Description:Write a TSQL function that as an input takes FlightPNR and extracts from this field all details about flight connection (segments)
----------------------------------------------------------------------

-- initialize 
declare @flight_details    varchar(8000) = 
'
        RP/ABCB23129/ABCB23129            EK/RM  26SEP16/1852Z   2B82OU
          1.SILVA/ARNALDO
          2  G31463 T 03OCT 4 IGUGIG HK1          1810 2009
          3  EK 248 Q 04OCT 5 GIGDXB HK1       2  0206 2305   *1A/E*
          4  EK 957 Q 05OCT 6 DXBBEY HK1       3  0720 1030   *1A/E*
          5  EK 954 Q 30OCT 3 BEYDXB HK1          1925 0115+1 *1A/E*
          6  EK 247 Q 31OCT 4 DXBGIG HK1       3  0710 1537   *1A/E*
          7  G31462 T 31OCT 4 GIGIGU HK1       1  2200 2359
          8 AP AGENCYTUR 55 42 3333 1117 A/C ALESSANDRA
          9 TK XL29SEP/ABCB23129
         10 SSR OTHS 1A ITIN CONFIRMED - MUST PROVIDE PAYMENT
         11 SSR OTHS 1A SUBJ CXL ON/BEFORE 03OCT 2109Z WITHOUT PAYMENT
         12 SSR OTHS 1A RITL/ PLS ADV TKT NOS BY 30SEP13 09 51 IGU LT
         13 FE PAX NON-END/SKYWARDS SAVER CHK-IN REWARD-UPGRADE/S2-7
        14 FV PAX EK/S2-7
'

create table #pnr_his 
(
       flight_HIS          varchar(8000)
      ,flight_connum       int 
      ,flight_alcode       varchar(3)
      ,flight_num          varchar(4)
      ,flight_booking      varchar(1)
      ,flight_day          varchar(2)
      ,flight_month        varchar(3)
      ,flight_weekday      varchar(1)
      ,flight_date         varchar(15)
      ,flight_year         varchar(4)
      ,flight_a1           varchar(3)
      ,flight_a2           varchar(3)
      ,flight_status       varchar(2)
      ,flight_paxno        varchar(2)
      ,flight_deptime      varchar(4)
      ,flight_arrtime      varchar(4)
      ,flight_daydiff      varchar(2)
      ,flight_fare_sum     varchar(10)
      ,flight_currency     varchar(10)
      ,flight_pta_num      varchar(15)
      ,flight_loc	   	   varchar(15)
      ,flight_amadeus      varchar(15)
)						  
						
-- declare parameters 
---------------------------------------------------------------
declare @flightpnr          varchar(8000) = @flight_details
declare @flightpnr2         varchar(8000) 

-- segment parts parameter
declare @flight_HIS         varchar(8000)
declare @flight_connum      int = 0
declare @flight_alcode      varchar(3)
declare @flight_num         varchar(4)
declare @flight_booking     varchar(1)
declare @flight_day         varchar(2)
declare @flight_month       varchar(3)
declare @flight_weekday     varchar(1)
declare @flight_date        varchar(15)
declare @flight_year        varchar(4)
declare @flight_a1          varchar(3)
declare @flight_a2          varchar(3)
declare @flight_status      varchar(2)
declare @flight_paxno       varchar(2)
declare @flight_deptime     varchar(4)
declare @flight_arrtime     varchar(4)
declare @flight_daydiff     varchar(2)
declare @flight_fare        varchar(10)
declare @flight_fare2       varchar(10)
declare @flight_currency    varchar(10)
declare @flight_sum         numeric(16,2)
declare @flight_pta_num     varchar(15)
declare @flight_loc         varchar(15)
declare @flight_amadeus     varchar(15)
    
-- segment parts parameter position 
declare @flight_alcode_pos  int = 0
declare @flight_num_pos     int = 0
declare @flight_booking_pos int = 0
declare @flight_day_pos     int = 0
declare @flight_month_pos   int = 0
declare @flight_weekday_pos int = 0
declare @flight_a1_pos      int = 0
declare @flight_a2_pos      int = 0
declare @flight_status_pos  int = 0
declare @flight_paxno_pos   int = 0 
declare @flight_deptime_pos int = 0   
declare @flight_arrtime_pos int = 0     
declare @flight_daydiff_pos int = 0
declare @flight_fare_pos    int = 0
declare @flight_fare_pos2   int = 0
declare @flight_pta_pos     int = 0
declare @flight_loc_pos     int = 0
declare @flight_amadeus_pos int = 0

-- declare loop parameters            
declare @max_counter        int
declare @loop_counter       int = 0
declare @loop_counter2      int = 0
declare @month              varchar(3)

-- declare checks
declare @flight_lly         varchar(4)
declare @flight_rly         varchar(4)
                
-- sanitize flight pnr              
 select @flightpnr2  = coalesce( @flightpnr2 + ' ' 
                     + case 
                           when len(value) = 5 
                            and right(value, len(value) - 2) 
                             in ('JAN ', 'FEB ', 'MAR ','APR ', 'MAY ', 'JUN ', 'JUL ', 'AUG ', 'SEP ', 'OCT ', 'NOV ', 'DEC ', 'MAI ', 'OKT ', 'DEZ ')
                                then( value +   right ('00'+ltrim(str(ROW_NUMBER() OVER(ORDER BY (SELECT 1)))),2))
                           when len(value) = 3
                            and isnumeric(substring( @flightpnr, charindex(value, @flightpnr collate latin1_general_cs_as) -2,1)) = 1
                            and value
                             in ('JAN ', 'FEB ', 'MAR ','APR ', 'MAY ', 'JUN ', 'JUL ', 'AUG ', 'SEP ', 'OCT ', 'NOV ', 'DEC ', 'MAI ', 'OKT ', 'DEZ ')
                                then( value +   right ('00'+ltrim(str(ROW_NUMBER() OVER(ORDER BY (SELECT 1)))),2))
                           else value
                        end 
                      , value)
   from string_split (@flightpnr, ' ') 
    set @flightpnr2   = replace(replace(replace(replace(replace(replace(@flightpnr2,char(13),' '),char(10),' '),char(9),' '), '    ', ' '),'   ', ' '),'  ', ' ')

-- declare cursor 
---------------------------------------------------------------
declare create_flight_HIS cursor for

 -- Select should match the number of parameters and datatype that are going to be used
 -- find all months in the PNR
 select case 
             when len(value) = 5
                  then charindex(value, @flightpnr2 collate latin1_general_cs_as)
             when len(value) = 7 
                  then charindex(value, @flightpnr2 collate latin1_general_cs_as) + 2 
         end as [location]
   from string_split(@flightpnr2, ' ')  
  where value != ' '
     -- 11JAN11
    and (len(value) = 7
    and left(right(value, len(value) - 2), len(right(value, len(value) - 2)) - 2)
     in ('JAN ', 'FEB ', 'MAR ','APR ', 'MAY ', 'JUN ', 'JUL ', 'AUG ', 'SEP ', 'OCT ', 'NOV ', 'DEC ', 'MAI ', 'OKT ', 'DEZ '))
     -- 11 JAN11
     or (len(value) = 5
    and isnumeric(substring( @flightpnr2, charindex(value, @flightpnr2 collate latin1_general_cs_as) -2,1)) = 1
    and left(value, len(value) - 2) 
     in ('JAN ', 'FEB ', 'MAR ','APR ', 'MAY ', 'JUN ', 'JUL ', 'AUG ', 'SEP ', 'OCT ', 'NOV ', 'DEC ', 'MAI ', 'OKT ', 'DEZ '))

-- store cursor values from select into the parameters
---------------------------------------------------------------
   open create_flight_HIS
  fetch next from create_flight_HIS into @flight_month_pos

        -- start process here
        while @@fetch_status = 0  
        begin  
             
             select @flight_alcode      = ''
                   ,@flight_num         = ''
                   ,@flight_booking     = ''
                   ,@flight_day         = ''
                   ,@flight_month       = substring(@flightpnr2, @flight_month_pos, 3)  
                   ,@flight_weekday     = ''
                   ,@flight_date        = ''
                   ,@flight_year        = ''
                   ,@flight_a1          = ''
                   ,@flight_a2          = ''
                   ,@flight_status      = ''
                   ,@flight_paxno       = ''
                   ,@flight_deptime     = ''
                   ,@flight_arrtime     = ''
                   ,@flight_daydiff     = ''
                   ,@flight_his         = ''
                   ,@flight_alcode_pos  = 0
                   ,@flight_num_pos     = 0
                   ,@flight_booking_pos = 0
                   ,@flight_day_pos     = 0
                   ,@flight_weekday_pos = 0 
                   ,@flight_a1_pos      = 0
                   ,@flight_a2_pos      = 0
                   ,@flight_status_pos  = 0
                   ,@flight_paxno_pos   = 0
                   ,@flight_deptime_pos = 0   
                   ,@flight_arrtime_pos = 0    
                   ,@flight_daydiff_pos = 0 
                   ,@flight_lly         = 0
                   ,@flight_rly         = 0
                   
             -- get the @flight_day
                set @loop_counter  = 1
              while @loop_counter <= 3 -- there can be space between day and month, thus the extra loop counter
              begin   
                    -- if substring before the month is numeric, it might be flight date
                    if isnumeric(substring(@flightpnr2, @flight_month_pos - @loop_counter, 1)) = 1
                    begin                   
                          set @flight_day     = substring(@flightpnr2, @flight_month_pos - @loop_counter, 1) + isnull(@flight_day, '') 
                          set @flight_day_pos = @flight_month_pos - @loop_counter
                    end                 
                    set @loop_counter = @loop_counter + 1 
                end 

             -- get the @flight_booking
                set @loop_counter  = 1
              while @loop_counter <= 2
              begin 
                    -- if substring before flight date is space + single non numeric character + space, might be flight booking
                    if  substring(@flightpnr2, @flight_day_pos -  @loop_counter     ,1 ) = ' ' 
                    and substring(@flightpnr2, @flight_day_pos - (@loop_counter + 1), 1) like '%[a-zA-Z]%'
                    and substring(@flightpnr2, @flight_day_pos - (@loop_counter + 2), 1) = ' ' 
                    begin               
                         set @flight_booking     = substring(@flightpnr2, @flight_day_pos - (@loop_counter + 1) ,1)
                         set @flight_booking_pos = @flight_day_pos - (@loop_counter + 1)                 
                    end
                    set @loop_counter = @loop_counter + 1                   
                end 

             -- get the flight number
                set @loop_counter  = 1
                set @loop_counter2 = 0
              while @loop_counter <= 4 
              begin -- check if character from the left of the flight day is numeric 
                    if  isnumeric(substring(@flightpnr2, @flight_day_pos -  @loop_counter, 1))      = 1
                    and isnumeric(substring(@flightpnr2, @flight_day_pos - (@loop_counter + 1), 1)) = 1
                    begin          
                        -- get the next 3 characters from the detected numeric
                        while @loop_counter2 < 4
                        begin 
                              if isnumeric(substring(@flightpnr2, @flight_day_pos -  (@loop_counter + @loop_counter2), 1)) = 1 
                              begin                           
                                 if @loop_counter2 != 3
                                 begin 
                                    set @flight_num     = substring(@flightpnr2, @flight_day_pos -  (@loop_counter + @loop_counter2), 1) + @flight_num      
                                    set @flight_num_pos = @flight_day_pos - (@loop_counter + @loop_counter2)       
                                 end 
                                 else if @loop_counter2 = 3
                                 and substring(@flightpnr2, @flight_day_pos -  (@loop_counter + @loop_counter2), 1)     != ''
                                 and substring(@flightpnr2, @flight_day_pos -  (@loop_counter + @loop_counter2 + 1), 1) != ''
                                 and substring(@flightpnr2, @flight_day_pos -  (@loop_counter + @loop_counter2 + 2), 1)  = ' '                            
                                 begin 
                                     break;
                                 end 
                                 else
                                 begin
                                    set @flight_num     = substring(@flightpnr2, @flight_day_pos -  (@loop_counter + @loop_counter2), 1) + @flight_num      
                                    set @flight_num_pos = @flight_day_pos - (@loop_counter + @loop_counter2)       
                                 end                                         
                              end                            
                              set @loop_counter2 = @loop_counter2 + 1 
                        end
                        break;
                    end
                    else if isnumeric(substring(@flightpnr2, @flight_day_pos -  @loop_counter, 1)) = 1
                    and  substring(@flightpnr2, @flight_day_pos - (@loop_counter + 1), 1)          = '  '
                    begin       
                        -- get the only character                      
                         set @flight_num     = '   ' + substring(@flightpnr2, @flight_day_pos - @loop_counter, 1) 
                         set @flight_num_pos = @flight_day_pos - @loop_counter                                        
                    end 
                    set @loop_counter = @loop_counter + 1 
                end 
           
              set   @loop_counter2 = 0
              if    substring(@flightpnr2, @flight_num_pos, 1) = '0' 
              begin
                    while @loop_counter2 < 2
                    begin 
                          if substring(@flightpnr2, @flight_num_pos + @loop_counter2, 1) = '0' 
                          begin
                          
                            set @flight_num = RIGHT(@flight_num, (LEN(@flight_num) - 1) )   
                          end  
                          set @loop_counter2 = @loop_counter2 + 1 
                    end 
              end 


                 -- if flight number is null use flight day else use flight number to find airline code 
                 if @flight_num = ''
              begin 
                       -- get the flight alcode 
                      set @loop_counter  = 1
                      set @loop_counter2 = 0
                    while @loop_counter <= 4 
                    begin 
                          if  substring(@flightpnr2, @flight_day_pos -  @loop_counter, 1)      like '%[a-zA-Z0-9]%'
                          and substring(@flightpnr2, @flight_day_pos - (@loop_counter + 1), 1) like '%[a-zA-Z0-9]%'
                          and(substring(@flightpnr2, @flight_day_pos - (@loop_counter + 2), 1) like '%[a-zA-Z0-9]%'
                          and substring(@flightpnr2, @flight_day_pos - (@loop_counter + 2), 1) = ' '
                           or substring(@flightpnr2, @flight_day_pos - (@loop_counter + 2), 1) = ''
                           or isnumeric(substring(@flightpnr2, @flight_num_pos - (@loop_counter + 2), 1)) = 1)
                          begin 
                               while @loop_counter2 < 2
                               begin 
                                     set @flight_alcode     = substring(@flightpnr2, @flight_day_pos - (@loop_counter + @loop_counter2), 1) + @flight_alcode
                                     set @flight_alcode_pos =  @flight_day_pos - (@loop_counter + @loop_counter2)
                                     set @loop_counter2 = @loop_counter2 + 1 
                               end                              
                          end
                          set @loop_counter = @loop_counter + 1 
                      end  
                end
               else 
              begin 
                       -- get the flight alcode 
                      set @loop_counter  = 1
                      set @loop_counter2 = 0
                    while @loop_counter <= 2
                    begin 
                          if  substring(@flightpnr2, @flight_num_pos -  @loop_counter, 1)      like '%[a-zA-Z0-9]%'
                          and substring(@flightpnr2, @flight_num_pos - (@loop_counter + 1), 1) like '%[a-zA-Z0-9]%'
                          and(substring(@flightpnr2, @flight_num_pos - (@loop_counter + 2), 1) like '%[a-zA-Z0-9]%'
                          and substring(@flightpnr2, @flight_num_pos - (@loop_counter + 2), 1) = ' '
                           or substring(@flightpnr2, @flight_num_pos - (@loop_counter + 2), 1) = ''
                           or isnumeric(substring(@flightpnr2, @flight_num_pos - (@loop_counter + 2), 1)) = 1)
                          begin 

                                while @loop_counter2 < 2
                                begin 
                                    set @flight_alcode     = substring(@flightpnr2, @flight_num_pos - (@loop_counter + @loop_counter2), 1) + @flight_alcode
                                    set @flight_alcode_pos =  @flight_num_pos - (@loop_counter + @loop_counter2)
                                    set @loop_counter2 = @loop_counter2 + 1 
                                end                                 
                          end
                          set @loop_counter = @loop_counter + 1 
                      end              
                end          
             

             -- get the flight week day             
                set @loop_counter  = 3
              while @loop_counter <= 10 
              begin  
                    if (substring(@flightpnr2, @flight_month_pos + @loop_counter, 1) = ' '
                    or  substring(@flightpnr2, @flight_month_pos + @loop_counter, 1) = '(')
                    and isnumeric(substring(@flightpnr2, @flight_month_pos + (@loop_counter +  1), 1)) = 1
                    and(substring(@flightpnr2, @flight_month_pos + (@loop_counter + 2),1) = ' '
                     or substring(@flightpnr2, @flight_month_pos + (@loop_counter + 2),1) = ')'
                     or substring(@flightpnr2, @flight_month_pos + (@loop_counter + 2),1) = '*')
                    begin                   
                         set @flight_weekday     = substring(@flightpnr2, @flight_month_pos + (@loop_counter + 1), 1)
                         set @flight_weekday_pos = @flight_month_pos + (@loop_counter + 1)              
                    end                 
                    set @loop_counter = @loop_counter + 1 
                end 

             -- get flight year
                 if @flight_weekday != '' 
                 begin
                      set @loop_counter  = 0
                    while @loop_counter <= (YEAR(getdate()) - 2000)
                    begin 
                          if(select case datename(weekday,@flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()) + @loop_counter))) 
                                         when 'monday'    then '1'
                                         when 'tuesday'   then '2'
                                         when 'wednesday' then '3'
                                         when 'thursday'  then '4'
                                         when 'friday'    then '5'
                                         when 'saturday'  then '6'
                                         when 'sunday'    then '7'
                                    end) = @flight_weekday
                          and @flight_year = ''
                          begin                           
                              select @flight_rly = convert(varchar(4),(YEAR(getdate()) + @loop_counter))
                              break;
                          end 
                          set @loop_counter = @loop_counter + 1   
                    end 

                      set @loop_counter  = 0
                    while @loop_counter <= (YEAR(getdate()) - 2000)
                    begin 
                          if(select case datename(weekday,@flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()) - @loop_counter))) 
                                            when 'monday'    then '1'
                                            when 'tuesday'   then '2'
                                            when 'wednesday' then '3'
                                            when 'thursday'  then '4'
                                            when 'friday'    then '5'
                                            when 'saturday'  then '6'
                                            when 'sunday'    then '7'
                                     end) = @flight_weekday
                          and @flight_year = ''
                          begin                           
                              select @flight_lly = convert(varchar(4),(YEAR(getdate()) - @loop_counter))
                              break;
                          end 
                          set @loop_counter = @loop_counter + 1   
                    end 

                    if (year(getdate()) - @flight_lly) < (@flight_rly - year(getdate()))
                    begin 
                         set @flight_year = @flight_lly
                    end 
                    else 
                    begin
                         set @flight_year = @flight_rly
                    end 

                end 
                else if @flight_weekday = '' 
                begin 
                     set @flight_year = datepart(yy, getdate())
                     --  if booking in jan or feb for nov or dec then year is previous year
                     if  datepart(MM,getdate()) in (1,2)
                     and isdate(@flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()) - 1 ))) = 1
                     begin
                          if datepart(MM, @flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()))))  = 10 
                          or datepart(MM, @flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()))))  = 11
                          or datepart(MM, @flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()))))  = 12
                          begin
                             set @flight_year = datepart(yy, getdate()) - 1 
                          end 
                         
                     end
                     else if datepart(MM,getdate()) = 3 
                     and isdate(@flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()) - 1 ))) = 1
                     begin
                           if datepart(MM, @flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()))))  = 11
                           or datepart(MM, @flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()))))  = 12
                           begin
                              set @flight_year = datepart(yy, getdate()) - 1 
                           end     
                     end 
                     else if datepart(MM,getdate()) = 10 
                     and isdate(@flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()) + 1 ))) = 1
                     begin
                           if datepart(MM, @flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate())))) = 1
                           or datepart(MM, @flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate())))) = 2
                           begin
                              set @flight_year = datepart(yy, getdate()) + 1 
                           end   
                     end 
                     -- if booking in nov or dec for jan or feb then year is next year
                     else if datepart(MM,getdate()) in (11,12)
                     and isdate(@flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()) + 1 ))) = 1
                     begin
                           if datepart(MM, @flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()))))  = 1
                           or datepart(MM, @flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()))))  = 2
                           or datepart(MM, @flight_month + ' ' + @flight_day + ' ' + convert(varchar(4),(YEAR(getdate()))))  = 3
                           begin
                              set @flight_year = datepart(yy, getdate()) + 1 
                           end    
                     end
                     else if @flight_month = 'feb' and @flight_day = '29'
                     begin 
                          
                          set   @loop_counter  = 0
                          while @loop_counter  < (YEAR(getdate()) - 2000) 
                          begin 
                                if (YEAR(getdate())+ @loop_counter) % 4 = 0
                                begin                           
                                    select @flight_lly = convert(varchar(4),(YEAR(getdate()) + @loop_counter))
                                    break;
                                end 
                                set @loop_counter = @loop_counter + 1   
                          end   

                          set   @loop_counter  = 0 
                          while @loop_counter < (YEAR(getdate()) - 2000) 
                          begin 
                                if (YEAR(getdate()) - @loop_counter) % 4 = 0
                                begin                           
                                    select @flight_rly = convert(varchar(4),(YEAR(getdate()) - @loop_counter))
                                    break;
                                end 
                                set @loop_counter = @loop_counter + 1   
                          end   

                          if (@flight_lly - year(getdate())) < (year(getdate()) - @flight_rly)
                          begin 
                               set @flight_year = @flight_lly
                          end 
                          else 
                          begin
                               set @flight_year = @flight_rly
                          end 

                     end
        
                end

             -- get the flight al from
                set @loop_counter  = 1
                set @loop_counter2 = 0
              while @loop_counter <= 4
              begin              
                    -- check if character from the right of the month is a 3 string char
                    if  substring(@flightpnr2, (@flight_month_pos + 4) + @loop_counter    , 1) like '%[a-zA-Z]%'
                    and substring(@flightpnr2, (@flight_month_pos + 4) + @loop_counter + 1, 1) like '%[a-zA-Z]%'
                    and substring(@flightpnr2, (@flight_month_pos + 4) + @loop_counter + 2, 1) like '%[a-zA-Z]%'
                    begin               
                        while @loop_counter2 <= 2
                        begin 
                              set @flight_a1     = @flight_a1 + substring(@flightpnr2, (@flight_month_pos + 4) + (@loop_counter + @loop_counter2), 1)       
                              set @flight_a1_pos = (@flight_month_pos + 4) + (@loop_counter + @loop_counter2)
                              set @loop_counter2 = @loop_counter2 + 1  
                       end             
                    end            
                    set @loop_counter = @loop_counter + 1           
                end 

             -- get the flight al to
                set @loop_counter   = 1
                set @loop_counter2  = 0
                 if @flight_a1_pos != 0
              begin 
                    while @loop_counter <= 2 
                    begin                    
                          if substring(@flightpnr2, @flight_a1_pos + @loop_counter, 1) != ' '
                          begin                      
                                -- check if character from the right of the month is a 3 string char
                                if  substring(@flightpnr2, @flight_a1_pos + @loop_counter + @loop_counter2    , 1) like '%[a-zA-Z]%'
                                and substring(@flightpnr2, @flight_a1_pos + @loop_counter + @loop_counter2 + 1, 1) like '%[a-zA-Z]%'
                                and substring(@flightpnr2, @flight_a1_pos + @loop_counter + @loop_counter2 + 2, 1) like '%[a-zA-Z]%'
                                begin               
                                    while @loop_counter2 <= 2
                                    begin 
                                          set @flight_a2     = @flight_a2 + substring(@flightpnr2, @flight_a1_pos + @loop_counter + @loop_counter2 , 1)     
                                          set @flight_a2_pos = @flight_a1_pos + @loop_counter + @loop_counter2 
                                          set @loop_counter2 = @loop_counter2 + 1   
                                    end             
                                end    
                          end
                          set @loop_counter = @loop_counter + 1 
                    end                     
                end 
        
            -- get the flight_status 
               set @loop_counter   = 1
               set @loop_counter2  = 0
             while @loop_counter  <= 3
             begin
                   if substring(@flightpnr2, @flight_a2_pos + @loop_counter, 1) != ' '
                   begin
                      while @loop_counter2 <= 1
                      begin 
                            if substring(@flightpnr2, @flight_a2_pos + (@loop_counter + @loop_counter2), 1) like '%[a-zA-Z]%' 
                            begin       
                               set @flight_status     = @flight_status + substring(@flightpnr2, @flight_a2_pos + (@loop_counter + @loop_counter2), 1)   
                               set @flight_status_pos = @flight_a2_pos + (@loop_counter + @loop_counter2)
                            end                       
                            set @loop_counter2     = @loop_counter2 + 1 
                      end                           
                   end
                   set @loop_counter = @loop_counter + 1 
             end

             -- get the flight_paxno
             if @flight_status_pos <> 0
             begin
                    set @loop_counter   = 1
                    set @loop_counter2  = 0
                  while @loop_counter  <= 2
                  begin 
                        while @loop_counter2 <= 1
                        begin 
                              if (isnumeric(substring(@flightpnr2, @flight_status_pos + (@loop_counter + @loop_counter2), 1)) = 1 
                              and isnumeric(substring(@flightpnr2, @flight_status_pos + (@loop_counter + @loop_counter2 + 1 ), 1)) = 1 
                              and substring(@flightpnr2, @flight_status_pos + (@loop_counter + @loop_counter2 + 2 ), 1) = ' ') 
                              or (isnumeric(substring(@flightpnr2, @flight_status_pos + (@loop_counter + @loop_counter2), 1)) = 1 
                              and substring(@flightpnr2, @flight_status_pos + (@loop_counter + @loop_counter2 + 1 ), 1) = ' ')   
                              begin       
                                 set @flight_paxno     = @flight_paxno  + substring(@flightpnr2, @flight_status_pos + (@loop_counter + @loop_counter2), 1)    
                                 set @flight_paxno_pos = @flight_status_pos + (@loop_counter + @loop_counter2)
                              end                       
                              set @loop_counter2       = @loop_counter2 + 1 
                        end  
                        set @loop_counter = @loop_counter + 1 
                  end 
             end
                            

             -- get the flight departure
                set @loop_counter  = 1
                set @loop_counter2 = 0
              while @loop_counter <= 10 
              begin -- check if character from the right of the flight airport to is numeric 
                    if  isnumeric(substring(@flightpnr2, @flight_a2_pos + @loop_counter, 1)) = 1 
                    and isnumeric(substring(@flightpnr2, @flight_a2_pos + @loop_counter + 1, 1)) = 1 
                    and isnumeric(substring(@flightpnr2, @flight_a2_pos + @loop_counter + 2, 1)) = 1 
                    and isnumeric(substring(@flightpnr2, @flight_a2_pos + @loop_counter + 3, 1)) = 1 
                    begin          
                        -- get the next 3 characters from the detected numeric
                        while @loop_counter2 < 4
                        begin 
                              if isnumeric(substring(@flightpnr2, @flight_a2_pos +  (@loop_counter + @loop_counter2), 1)) = 1 
                              begin
                                 set @flight_deptime     = @flight_deptime + substring(@flightpnr2, @flight_a2_pos + (@loop_counter + @loop_counter2), 1)       
                                 set @flight_deptime_pos = @flight_a2_pos + (@loop_counter + @loop_counter2)                                 
                              end                                               
                              set @loop_counter2 = @loop_counter2 + 1 
                        end
                    end
                    set @loop_counter = @loop_counter + 1 
                end 

             -- get the flight arrival
                set @loop_counter  = 1
                set @loop_counter2 = 0
              while @loop_counter <= 10 
              begin -- check if character from the right of the flight airport to is numeric 
                    if  isnumeric(substring(@flightpnr2, @flight_deptime_pos + @loop_counter, 1    )) = 1 
                    and isnumeric(substring(@flightpnr2, @flight_deptime_pos + @loop_counter + 1, 1)) = 1 
                    and isnumeric(substring(@flightpnr2, @flight_deptime_pos + @loop_counter + 2, 1)) = 1 
                    and isnumeric(substring(@flightpnr2, @flight_deptime_pos + @loop_counter + 3, 1)) = 1 
                    begin          
                        -- get the next 3 characters from the detected numeric
                        while @loop_counter2 < 4
                        begin 
                              if isnumeric(substring(@flightpnr2, @flight_deptime_pos +  (@loop_counter + @loop_counter2), 1)) = 1 
                              begin
                                 set @flight_arrtime     = @flight_arrtime + substring(@flightpnr2, @flight_deptime_pos + (@loop_counter + @loop_counter2), 1)      
                                 set @flight_arrtime_pos = @flight_deptime_pos + (@loop_counter + @loop_counter2)                            
                              end                                               
                              set @loop_counter2 = @loop_counter2 + 1 
                        end 
                    end
                    set @loop_counter = @loop_counter + 1 
                end 
          
             -- get the flight arrival
                set @loop_counter  = 1
                set @loop_counter2 = 0
              while @loop_counter <= 10 
              begin -- check if character from the right of the flight airport to is numeric 
                    if  isnumeric(substring(@flightpnr2, @flight_deptime_pos + @loop_counter, 1    )) = 1 
                    and isnumeric(substring(@flightpnr2, @flight_deptime_pos + @loop_counter + 1, 1)) = 1 
                    and isnumeric(substring(@flightpnr2, @flight_deptime_pos + @loop_counter + 2, 1)) = 1 
                    and isnumeric(substring(@flightpnr2, @flight_deptime_pos + @loop_counter + 3, 1)) = 1 
                    begin          
                        -- get the next 3 characters from the detected numeric
                        while @loop_counter2 < 4
                        begin 
                              if isnumeric(substring(@flightpnr2, @flight_deptime_pos +  (@loop_counter + @loop_counter2), 1)) = 1 
                              begin
                                 set @flight_arrtime     = @flight_arrtime + substring(@flightpnr2, @flight_deptime_pos + (@loop_counter + @loop_counter2), 1)      
                                 set @flight_arrtime_pos = @flight_deptime_pos + (@loop_counter + @loop_counter2)                            
                              end                                               
                              set @loop_counter2 = @loop_counter2 + 1 
                        end 
                    end
                    set @loop_counter = @loop_counter + 1 
                end 
          
           -- get the flight day diff
            if substring(@flightpnr2, @flight_arrtime_pos - 4, 1)        = '#'
            or substring(@flightpnr2, @flight_arrtime_pos - (4 + 1 ), 1) = '#'
            begin 
                 set @flight_daydiff = '+1'
            end 

            if @flight_daydiff = '' and @flight_arrtime != ''
            begin              
                 set @loop_counter  = 1
                 set @loop_counter2 = 0
               while @loop_counter <= 8
               begin -- check if character from the right of the flight arrival is started by '+'             
                     if  substring(@flightpnr2, @flight_arrtime_pos + @loop_counter, 1) = '+'
                     and(isnumeric(substring(@flightpnr2, @flight_arrtime_pos + @loop_counter + 1, 1)) = 1 
                     or  substring(@flightpnr2, @flight_arrtime_pos + @loop_counter + 1, 1) = ' '
                     and isnumeric(substring(@flightpnr2, @flight_arrtime_pos + @loop_counter + 2, 1))= 1 )  
                     begin 
                      -- get the next 2 characters from the detected string 
                         while @loop_counter2 <= 3
                         begin 
                               if substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + @loop_counter2), 1) != ' '
                               begin
                                    set @flight_daydiff     = @flight_daydiff + substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + @loop_counter2), 1)         
                                    set @flight_daydiff_pos = @flight_arrtime_pos + (@loop_counter + @loop_counter2)                                        
                               end
                               set @loop_counter2 = @loop_counter2 + 1 
                               
                         end                                                                         
                     end 
                     else if isnumeric(substring(@flightpnr2, @flight_arrtime_pos + @loop_counter, 1))       = 1 
                     and     isnumeric(substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 1), 1)) = 1 
                     and     substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 2), 1)            like '%[a-zA-Z]%' 
                     and     substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 3), 1)            like '%[a-zA-Z]%' 
                     and     substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 4), 1)            like '%[a-zA-Z]%' 
                     and        isdate(substring(@flightpnr2, @flight_arrtime_pos + @loop_counter, 1)     
                                      +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 1), 1)
                                      +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 2), 1) 
                                      +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 3), 1) 
                                      +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 4), 1) 
                                      + @flight_year) = 1                      
                     begin 
                          -- flight date is greater than the extra date after arrival time then 
                          -- and flight date is from december
                          -- extra date is from next year 
                          -- 11DEC2022 -> 11JAN2022 must be 11DEC2022 -> 11JAN2023
                          if(datepart(dayofyear,@flight_day + @flight_month + @flight_year) >
                             datepart(dayofyear,
                             substring(@flightpnr2, @flight_arrtime_pos + @loop_counter      , 1)     
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 1), 1)
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 2), 1) 
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 3), 1) 
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 4), 1) 
                            + @flight_year))
                          and datepart(mm,@flight_day + @flight_month + @flight_year) = 12  
                          and datepart(mm,
                             substring(@flightpnr2, @flight_arrtime_pos + @loop_counter      , 1)     
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 1), 1)
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 2), 1) 
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 3), 1) 
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 4), 1) 
                            + @flight_year) != 12
                          begin 
                                select @flight_daydiff =  '+' 
                                                          +convert(varchar(3),datediff( day
                                                          ,@flight_day + @flight_month + @flight_year
                                                          ,substring(@flightpnr2, @flight_arrtime_pos + @loop_counter,   1)     
                                                          +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 1), 1)
                                                          +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 2), 1) 
                                                          +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 3), 1) 
                                                          +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 4), 1) 
                                                          +convert(varchar(4),datepart(yy,dateadd(year,1,'JAN '+'01 '+ @flight_year)))))    
                        
                          end 
                          -- flight date is smaller than the extra date after arrival time then 
                          -- 30DEC2022 -> 31DEC2022 should be + 1
                          else if(datepart(dayofyear,@flight_day + @flight_month + @flight_year) <
                                  datepart(dayofyear,
                                  substring(@flightpnr2, @flight_arrtime_pos + @loop_counter      , 1)     
                                 +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 1), 1)
                                 +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 2), 1) 
                                 +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 3), 1) 
                                 +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 4), 1) 
                                 + @flight_year))
                          begin 
                                select @flight_daydiff =  '+' 
                                                          +convert(varchar(3),datediff( day
                                                          ,@flight_day + @flight_month + @flight_year
                                                          ,substring(@flightpnr2, @flight_arrtime_pos + @loop_counter,   1)     
                                                          +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 1), 1)
                                                          +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 2), 1) 
                                                          +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 3), 1) 
                                                          +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 4), 1) 
                                                          +convert(varchar(4),@flight_year)
                                                          ))    
                          end 
                          else if(datepart(dayofyear,@flight_day + @flight_month + @flight_year) >
                             datepart(dayofyear,
                             substring(@flightpnr2, @flight_arrtime_pos + @loop_counter      , 1)     
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 1), 1)
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 2), 1) 
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 3), 1) 
                            +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 4), 1) 
                            + @flight_year))
                          begin
                                select @flight_daydiff =  '-'
                                                         +convert(varchar(3),datediff( day                                                         
                                                         ,substring(@flightpnr2, @flight_arrtime_pos + @loop_counter,   1)     
                                                         +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 1), 1)
                                                         +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 2), 1) 
                                                         +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 3), 1) 
                                                         +substring(@flightpnr2, @flight_arrtime_pos + (@loop_counter + 4), 1) 
                                                         + @flight_year
                                                         ,@flight_day + @flight_month + @flight_year ))
                          
                          end       
                     end                                  

                     set @loop_counter = @loop_counter + 1 
                 end
            end 

        select @flight_connum = @flight_connum + 1
         where @flight_a1      != '' 
           and @flight_a2      != ''        
           and @flight_deptime != ''
           and @flight_arrtime != ''                

           set @flight_fare_pos = case 
                                      when patindex('%fare%', @flightpnr2) <> 0 and patindex('%EUR%', @flightpnr2) <> 0
                                           then (patindex('%fare%', @flightpnr2) - 1)  + patindex('%EUR%', substring(@flightpnr2,patindex('%fare%', @flightpnr2),100))
                                      when patindex('%fare%', @flightpnr2) <> 0 and patindex('%USD%', @flightpnr2) <> 0
                                           then (patindex('%fare%', @flightpnr2) - 1) + patindex('%USD%', substring(@flightpnr2,patindex('%fare%', @flightpnr2),100))
                                      else case 
                                                when patindex('%EUR%', @flightpnr2) <> 0
                                                     then patindex('%EUR%', @flightpnr2)
                                                else patindex('%USD%', @flightpnr2)
                                           end
                                  end 
           set @flight_currency = case 
                                       when patindex('%EUR%', @flightpnr2) <> 0
                                           then 'EUR'
                                       when patindex('%USD%', @flightpnr2) <> 0
                                           then 'USD'

                                  end
            
         if @flight_fare_pos > 0 and @flight_fare is null
         begin 
               -- checks where is the fare price string is from left or right cases: 1000EUR or EUR 1000
               if  substring(@flightpnr2, (@flight_fare_pos + 2) + 1,1 ) like '%[0-9 ]%'
               and substring(@flightpnr2, (@flight_fare_pos + 2) + 2,1 ) like '%[0-9]%'
               and substring(@flightpnr2, (@flight_fare_pos) - 1,1 ) not like '%[0-9]%'
               or  substring(@flightpnr2, (@flight_fare_pos + 2) + 1,1 ) = ':'
               begin 
                   -- select the next string after the word EUR
                   set   @flight_fare_pos += 3 
                   set   @loop_counter     = 1
                   while @loop_counter    <= 8
                   begin 
                         if substring(@flightpnr2, @flight_fare_pos,1 ) like '%[0-9.]%' 
                         begin 
                            set @flight_fare =  isnull(@flight_fare, '') + substring(@flightpnr2, @flight_fare_pos,1 )  
                         end
                         else if substring(@flightpnr2, @flight_fare_pos,1 ) = '(' 
                         or  (substring(@flightpnr2, @flight_fare_pos - 1, 1 ) like '%[0-9.]%' 
                         and substring(@flightpnr2, @flight_fare_pos,1 ) = ' ') 
                         begin 
                            break
                         end
                         -- select @flight_fare_pos as flight_fare_pos ,@flight_fare            
                         set @flight_fare_pos += 1
                         set @loop_counter = @loop_counter + 1 
                   end 
                
                   -- check for additional fares    
                   set @flight_fare_pos2 = case 
                                                when substring(@flightpnr2,@flight_fare_pos,10) like '%(%'
                                                     then 0
                                                when  patindex('%+%', substring(@flightpnr2,@flight_fare_pos,100)) <> 0 
                                                     then case
                                                              when patindex('%EUR%', substring(@flightpnr2,@flight_fare_pos,100)) <> 0
                                                                   then @flight_fare_pos + patindex('%EUR%', substring(@flightpnr2,@flight_fare_pos,100))
                                                              when patindex('%USD%', substring(@flightpnr2,@flight_fare_pos,100)) <> 0
                                                                   then @flight_fare_pos + patindex('%USD%', substring(@flightpnr2,@flight_fare_pos,100))
                                                              else 0
                                                          end
                                                else 0
                                           end

                   if  @flight_fare_pos2 > 0 and (@flight_fare_pos2 - @flight_fare_pos) <= 10
                   begin 
                        set   @loop_counter  = 1
                        while @loop_counter <= 8
                        begin           
                              if substring(@flightpnr2, @flight_fare_pos2,1 ) like '%[0-9.]%' 
                              begin
                                 set @flight_fare2 =  isnull(@flight_fare2, '') + substring(@flightpnr2, @flight_fare_pos2,1 )
                              end
                              -- select @flight_fare_pos as flight_fare_pos ,@flight_fare           
                              set @flight_fare_pos2 += 1
                              set @loop_counter = @loop_counter + 1                                
                        end               
                   end 
                   

                      
               end        
               -- If cost happens to be before the currency
               else if substring(@flightpnr2, (@flight_fare_pos) - 1,1 ) like '%[0-9 ]%'
               and substring(@flightpnr2, (@flight_fare_pos) - 2,1 ) like '%[0-9]%'
               begin
                    -- select the next string after the word EUR
                    set   @flight_fare_pos -= 1 
                    set   @loop_counter     = 1
                    while @loop_counter    <= 8
                    begin 
                          if substring(@flightpnr2, @flight_fare_pos,1 ) like '%[0-9.]%' 
                          begin 
                             set @flight_fare = substring(@flightpnr2, @flight_fare_pos,1 ) + isnull(@flight_fare, '')   
                          end   
                          else if substring(@flightpnr2, @flight_fare_pos + 1,1 ) like '%[0-9.]%' 
                          and substring(@flightpnr2, @flight_fare_pos,1 ) = ' ' 
                          begin
                             break;
                          end                      
                         
                          set @flight_fare_pos -= 1
                          set @loop_counter = @loop_counter + 1 
                    end 
           
                    set @flight_fare_pos  = case 
                                                 when patindex('%EUR%', @flightpnr2) <> 0
                                                      then patindex('%EUR%', @flightpnr2)
                                                 else patindex('%USD%', @flightpnr2)
                                            end + 2
                    
                    -- check for additional fares     
                    set @flight_fare_pos2 = case
                                                 when substring(@flightpnr2,@flight_fare_pos,10) like '%(%'
                                                      then 0 
                                                 when patindex('%+%', substring(@flightpnr2,@flight_fare_pos,100)) <> 0 
                                                      then case
                                                               when patindex('%EUR%', substring(@flightpnr2,@flight_fare_pos,100)) <> 0
                                                                   then @flight_fare_pos + patindex('%EUR%', substring(@flightpnr2,@flight_fare_pos,100))
                                                               when patindex('%USD%', substring(@flightpnr2,@flight_fare_pos,100)) <> 0
                                                                   then @flight_fare_pos + patindex('%USD%', substring(@flightpnr2,@flight_fare_pos,100))
                                                               else 0
                                                           end
                                                 else 0
                                            end
                
                                             if  @flight_fare_pos2 > 0 and (@flight_fare_pos2 - @flight_fare_pos) <= 20
                    begin 
                        set   @loop_counter  = 1
                        while @loop_counter <= 11
                        begin           
                              if substring(@flightpnr2, @flight_fare_pos2,1 ) like '%[0-9.]%' 
                              begin
                                     set @flight_fare2 = substring(@flightpnr2, @flight_fare_pos2,1 ) + isnull(@flight_fare2, '')
                              end           
                              set @flight_fare_pos2 -= 1
                              set @loop_counter = @loop_counter + 1                                
                        end               
                    end  
               end 
           end

        -- Check if line contains one of: "PTA ","PTA:","E-Tix No","ETix:","E.TKT NO:","e-tix No :","e-tix No:","e-ticket :","e-ticket:","e-tickets :","e-tickets :","ETIX:","ETIX :","E-TKT:","E-TKT :"
        select @flight_pta_pos = case 
                                      when patindex('%PTA%', @flightpnr2) > 0
                                           then patindex('%PTA%', @flightpnr2)
                                      when patindex('%E-Tix%', @flightpnr2) > 0
                                           then patindex('%E-Tix%', @flightpnr2) 
                                      when patindex('%E.TKT NO:%', @flightpnr2) > 0
                                           then patindex('%E.TKT NO:%', @flightpnr2) 
                                      when patindex('%e-ticket%', @flightpnr2) > 0
                                           then patindex('%e-ticket%', @flightpnr2) 
                                      when patindex('%E-TKT%', @flightpnr2) > 0
                                           then patindex('%E-TKT%', @flightpnr2) 
                                      when patindex('%ETix:%', @flightpnr2) > 0
                                           then patindex('%ETix:%', @flightpnr2)                                 
                                 end 
        
        if @flight_pta_pos > 0 and @flight_pta_num is null
        begin 
        
             -- check the start of the flight pta num
             set   @loop_counter     = 1
             while @loop_counter    <= 10
             begin 
                   if substring(@flightpnr2, @flight_pta_pos,1 ) like '%[0-9]%' 
                   begin 
                        break
                   end
                    
                   set @flight_pta_pos += 1
                   set @loop_counter = @loop_counter + 1 
             end 
        
             set   @loop_counter     = 1
             while @loop_counter    <= 14
             begin 
                   if substring(@flightpnr2, @flight_pta_pos,1 ) like '%[0-9-]%' 
                   begin 
                        set @flight_pta_num =  isnull(@flight_pta_num, '') + substring(@flightpnr2, @flight_pta_pos,1 )  
                   end
                
                   set @flight_pta_pos += 1
                   set @loop_counter = @loop_counter + 1 
             end 

             set @flight_pta_num = replace(@flight_pta_num, '-', '')
        end
           

         if 
        --not exists (select 1 
        --             where @flightpnr2 like '%amadeus%'
        --                or @flightpnr2 like '%sabre%'
        --                or @flightpnr2 like '%galileo%'
        --                or @flightpnr2 like '%worldspan%') 
        --and 
        isnull(@flight_loc,'') = ''
        begin 
             select @flight_loc_pos = case 
                                           when patindex('%locator%', @flightpnr2) > 0
                                                then patindex('%locator%', @flightpnr2)
                                           when patindex('%loc:%', @flightpnr2) > 0
                                                then patindex('%loc:%', @flightpnr2) 
                                           when patindex('%locators%', @flightpnr2) > 0
                                                then patindex('%locators%', @flightpnr2) 
                                           when patindex('%RecordLocator%', @flightpnr2) > 0
                                                then patindex('%RecordLocator%', @flightpnr2) 
                                           when patindex('%AIRLINEREF%', @flightpnr2) > 0
                                                then patindex('%AIRLINEREF%', @flightpnr2)                               
                                      end 

             -- check the start of the flight locator
             set   @loop_counter     = 1
             while @loop_counter    <= 15
             begin 
                   if substring(@flightpnr2, @flight_loc_pos,1) = ':' 
                   begin 
                        set @flight_loc_pos += 2
                        break
                   end
                   set @flight_loc_pos += 1
                   set @loop_counter = @loop_counter + 1 
             end 
                              
             -- continue the loop
             set   @loop_counter     = 1
             while @loop_counter    <= 10
             begin 
                   if substring(@flightpnr2, @flight_loc_pos,1) = ' ' 
                   begin 
                        break
                   end
                   set @flight_loc =  isnull(@flight_loc, '') + substring(@flightpnr2, @flight_loc_pos,1 )              
                   set @flight_loc_pos += 1
                   set @loop_counter = @loop_counter + 1        
             end 
         
             set @flight_loc = case
                                   when @flight_loc like '%/%'
                                        then Stuff(replace(@flight_loc, ' ', ''), 1, PATINDEX('%/%', @flight_loc), '')  
                                   else  replace(@flight_loc, ' ', '')
                               end                                  
        end 
        
        if exists (select 1 
                    where @flightpnr2 like '%amadeus%'
                       or @flightpnr2 like '%AmadeusLocator%') 
        and isnull(@flight_amadeus,'') = ''
        begin 
             set @flight_amadeus_pos = patindex('%amadeus%', @flightpnr2)
             -- check the start of the flight locator
             set   @loop_counter     = 1
             while @loop_counter    <= 15
             begin 
                   if substring(@flightpnr2, @flight_amadeus_pos,1) = ':' 
                   begin 
                        set @flight_amadeus_pos += 1
                        break
                   end              
                   set @flight_amadeus_pos += 1
                   set @loop_counter = @loop_counter + 1 
             end                
             -- continue the loop
             set   @loop_counter     = 1
             while @loop_counter    <= 6
             begin 
                   if substring(@flightpnr2, @flight_amadeus_pos,1) = ' ' 
                   begin 
                         set @flight_amadeus_pos += 1
                   end
                   else
                   begin
                         set @flight_amadeus =  isnull(@flight_amadeus, '') + substring(@flightpnr2, @flight_amadeus_pos,1 )            
                         set @flight_amadeus_pos += 1
                         set @loop_counter = @loop_counter + 1      
                   end                 
             end 
        end 

        select @flight_his = 
               convert(char(1),@flight_connum)
              +' '
              +case 
                    when len(@flight_num) <= 3
                         then isnull(@flight_alcode ,'') + ' '  
                    else isnull(@flight_alcode ,'')
               end
              +isnull(@flight_num    ,'') 
              +' '                   
              +isnull(@flight_day    ,'') 
              +isnull(@flight_month  ,'')
              +' '                   
              +isnull(@flight_a1     ,'')
              +isnull(@flight_a2     ,'')
              +' '                   
              +isnull(@flight_status ,'')
              +case 
                    when isnull(@flight_paxno  ,'') = '0'
                         then ''
                    else isnull(@flight_paxno  ,'') 
                end 
              +case 
                    when count(isnull(@flight_paxno  ,'')) = 1
                         then + ' '
                end 
              +' ' 
              +isnull(@flight_deptime,'')
              +isnull(' ' + @flight_arrtime,'')
              +case 
                    when @flight_daydiff like '%0%'
                         then ''
                    else @flight_daydiff
               end                   
              ,@flight_sum = case
                                  when @flight_sum is null
                                  then isnull(convert(numeric(16,2),@flight_fare),0) + isnull(convert(numeric(16,2),@flight_fare2),0)
                                  else @flight_sum  
                             end                                
                                 
        ---- construct segment
        insert into #pnr_his
        (
               flight_HIS        
              ,flight_connum     
              ,flight_alcode     
              ,flight_num        
              ,flight_booking    
              ,flight_day        
              ,flight_month      
              ,flight_weekday    
              ,flight_date       
              ,flight_year       
              ,flight_a1         
              ,flight_a2         
              ,flight_status     
              ,flight_paxno      
              ,flight_deptime    
              ,flight_arrtime    
              ,flight_daydiff   
              ,flight_fare_sum
              ,flight_currency
              ,flight_pta_num
              ,flight_loc
              ,flight_amadeus

        )
        select @flight_his          as flight_his
              ,@flight_connum       as flight_connum  
              ,@flight_alcode       as flight_alcode
              ,@flight_num          as flight_num
              ,@flight_booking      as flight_booking
              ,@flight_day          as flight_day          
              ,@flight_month        as flight_month  
              ,@flight_weekday      as flight_weekday
              ,case isdate(@flight_month + ' ' + @flight_day + ' ' + @flight_year)
                    when 1 
                         then @flight_month + ' ' + @flight_day + ' ' + @flight_year
                    else ''
               end as flight_date
              ,@flight_year         as flight_year 
              ,@flight_a1           as flight_a1
              ,@flight_a2           as flight_a2
              ,@flight_status       as flight_status    
              ,@flight_paxno        as flight_paxno
              ,@flight_deptime      as flight_deptime
              ,@flight_arrtime      as flight_arrtime
              ,case 
                    when @flight_daydiff like '%0%'
                         then ''
                    else @flight_daydiff
               end                  as flight_daydiff
              ,@flight_sum          as flight_sum
              ,@flight_currency     as flight_currency 
              ,@flight_pta_num      as flight_pta_num
              ,@flight_loc          as flight_loc
              ,@flight_amadeus      as flight_amadeus
         where @flight_a1      != '' 
           and @flight_a2      != ''        
           and @flight_deptime != ''
           and @flight_arrtime != ''
           and @flight_his     != ''

               -- fetch the next record from theloop
               fetch next from create_flight_HIS into @flight_month_pos 

           end
        
  -- close the cursor
  close      create_flight_HIS  
  deallocate create_flight_HIS

  select * from #pnr_his