#!/usr/bin/perl

#use lib "/common/appl/Perl/perl-5.8.8/lib/perl5/site_perl/5.8.8";
use lib "/shsv/MCUGr2/user/thuythanhnguyen/lib_excel/EXCEL";

#===============================================================================
#  Author : thuythanhnguyen 
#  History:
#       2022/08/17: change font of pattern from Calibri -> Courier for better allignment
#       2022/08/30: change for collect pattern from multiple directory
#===============================================================================

use warnings;

use Excel::Writer::XLSX;
use Shell qw (find ls cd pwd grep date whoami);

my $excel_name  = $ARGV[0];
my $OLD         = $ARGV[1];
my $NEW         = $ARGV[2];
my $date        = date ("+%d%b%Y");
my $usr         = whoami;
my $time        = date;
my $time_detail = date ("+%H%M%S");

my $lst_vimdiff     = ".vimdiff";
my $lst_tem_tinh    = ".tem_tinh";
my $lst_LIST_ALL    = ".LIST_ALL";
my $lst_COMMON      = ".COMMON";


chomp ($date);
chomp ($time);
chomp ($time_detail);
chomp ($usr);

my $workbook   = Excel::Writer::XLSX->new("$excel_name");

#print ("Processing");

#============== FORMAT ================
$workbook->set_custom_color(12,0,204,255);

my $ft_bold_cen = $workbook->add_format();
   $ft_bold_cen->set_pattern();
   $ft_bold_cen->set_bg_color('white');
   $ft_bold_cen->set_bold();
   $ft_bold_cen->set_border('1');
   $ft_bold_cen->set_align('center');
   $ft_bold_cen->set_valign('vcenter');
my $ft_bold_top = $workbook->add_format();
   $ft_bold_top->set_pattern();
   $ft_bold_top->set_bg_color('white');
   $ft_bold_top->set_bold();
   $ft_bold_top->set_border();
   $ft_bold_top->set_align('top');
my $ft_bold = $workbook->add_format();
   $ft_bold->set_bold();
my $ft_bolder = $workbook->add_format();
   $ft_bolder->set_bold();
   $ft_bolder->set_border('1');
my $ft_border = $workbook->add_format();
   $ft_border->set_border('1');
my $ft_border_c = $workbook->add_format();
   $ft_border_c->set_border('1');
   $ft_border_c->set_align('center');
   $ft_border_c->set_valign('vcenter');
my $ft_border2 = $workbook->add_format();
   $ft_border2->set_border('1');
   $ft_border2->set_align('center');
my $ft_merge = $workbook->add_format();
   $ft_merge->set_bold();
   $ft_merge->set_align('vcenter');
   $ft_merge->set_rotation(90);
   $ft_merge->set_border('2');
my $ft_merge_horizontal_small = $workbook->add_format();
   $ft_merge_horizontal_small->set_bold();
   $ft_merge_horizontal_small->set_align('center');
   $ft_merge_horizontal_small->set_valign('vcenter');
   $ft_merge_horizontal_small->set_size(24);
   $ft_merge_horizontal_small->set_font('Times New Roman');
my $ft_merge_horizontal= $workbook->add_format();
   $ft_merge_horizontal->set_bold();
   $ft_merge_horizontal->set_align('center');
   $ft_merge_horizontal->set_valign('vcenter');
   $ft_merge_horizontal->set_size(36);
   $ft_merge_horizontal->set_font('Times New Roman');
my $ft_merge_formal = $workbook->add_format();
   $ft_merge_formal->set_align('center');
   $ft_merge_formal->set_valign('vcenter');
   $ft_merge_formal->set_size(14);
   $ft_merge_formal->set_font('Times New Roman');
   $ft_merge_formal->set_border('1');
my $ft_merge_blue = $workbook->add_format();
   $ft_merge_blue->set_align('left');
   $ft_merge_blue->set_italic();
   $ft_merge_blue->set_valign('vcenter');
   $ft_merge_blue->set_size(11);
   $ft_merge_blue->set_font('Calibri');
   $ft_merge_blue->set_border('1');
   $ft_merge_blue->set_color(39);
my $ft_formal_bold = $workbook->add_format();
   $ft_formal_bold->set_bold();
   $ft_formal_bold->set_size(14);
   $ft_formal_bold->set_font('Arial');
my $ft_formal_border = $workbook->add_format();
   $ft_formal_border->set_border('1');
   $ft_formal_border->set_size(14);
   $ft_formal_border->set_font('Arial');
my $ft_formal_top = $workbook->add_format();
   $ft_formal_top->set_top('2');
   $ft_formal_top->set_size(14);
   $ft_formal_top->set_font('Times New Roman');
my $ft_Arial_20_bold = $workbook->add_format();
   $ft_Arial_20_bold->set_bold();
   $ft_Arial_20_bold->set_size(20);
   $ft_Arial_20_bold->set_font('Arial');
my $ft_Calibri_11 = $workbook->add_format();
   $ft_Calibri_11->set_size(11);
   $ft_Calibri_11->set_font('Calibri');
my $ft_Calibri_11_border = $workbook->add_format();
   $ft_Calibri_11_border->set_border('1');
   $ft_Calibri_11_border->set_size(11);
   $ft_Calibri_11_border->set_font('Calibri');
my $ft_Calibri_11_bold = $workbook->add_format();
   $ft_Calibri_11_bold->set_bold();
   $ft_Calibri_11_bold->set_size(11);
   $ft_Calibri_11_bold->set_font('Calibri');
my $ft_Calibri_11_bold_border = $workbook->add_format();
   $ft_Calibri_11_bold_border->set_bold();
   $ft_Calibri_11_bold_border->set_border('1');
   $ft_Calibri_11_bold_border->set_size(11);
   $ft_Calibri_11_bold_border->set_font('Calibri');
my $ft_Calibri_11_bold_border_2 = $workbook->add_format();
   $ft_Calibri_11_bold_border_2->set_bold();
   $ft_Calibri_11_bold_border_2->set_border('1');
   $ft_Calibri_11_bold_border_2->set_size(11);
   $ft_Calibri_11_bold_border_2->set_font('Calibri');
   $ft_Calibri_11_bold_border_2->set_bg_color('#FFC000');
my $ft_Calibri_11_red = $workbook->add_format();
   $ft_Calibri_11_red->set_size(11);
   $ft_Calibri_11_red->set_font('Calibri');
   $ft_Calibri_11_red->set_color('red');
my $ft_wrap = $workbook->add_format();
   $ft_wrap->set_border('1');
my $ft_bold_und = $workbook->add_format();
   $ft_bold_und->set_bold();
   $ft_bold_und->set_underline();
my $ft_line_diff = $workbook->add_format();
   $ft_line_diff->set_pattern();
   $ft_line_diff->set_left('1');
   $ft_line_diff->set_right('1');
   $ft_line_diff->set_bg_color(12);
my $ft_line_lr = $workbook->add_format();
   $ft_line_lr->set_pattern();
   $ft_line_lr->set_left('1');
   $ft_line_lr->set_right('1');
   $ft_line_lr->set_bg_color('white');
my $ft_line_t = $workbook->add_format();
   $ft_line_t->set_pattern();
   $ft_line_t->set_top('1');
   $ft_line_t->set_bg_color('white');
my $ft_mod = $workbook->add_format();
   $ft_mod->set_pattern();
   $ft_mod->set_bg_color('#F79646');
   $ft_mod->set_border('1');
my $ft_line_ecr = $workbook->add_format();
   $ft_line_ecr->set_pattern();
   $ft_line_ecr->set_bg_color('pink');
   $ft_line_ecr->set_border('1');
   $ft_line_ecr->set_bold();
my $ft_line_ecr2 = $workbook->add_format();
   $ft_line_ecr2->set_pattern();
   $ft_line_ecr2->set_bg_color(52);
   $ft_line_ecr2->set_border('1');
   $ft_line_ecr2->set_bold();
my $ft_new = $workbook->add_format();
   $ft_new->set_pattern();
   $ft_new->set_bg_color('yellow');
   $ft_new->set_border('1');
my $ft_del = $workbook->add_format();
   $ft_del->set_pattern();
   $ft_del->set_bg_color('gray');
   $ft_del->set_border('1');
my $ft_org = $workbook->add_format();
   $ft_org->set_pattern();
   $ft_org->set_border('1');
   $ft_org->set_bg_color('white');
my $ft_tittle = $workbook->add_format();
   $ft_tittle->set_pattern();
   $ft_tittle->set_bold();
   $ft_tittle->set_bg_color('blue');
   $ft_tittle->set_align('center');
   $ft_tittle->set_valign('top');
   $ft_tittle->set_border();
   $ft_tittle->set_text_wrap();
my $ft_yellow = $workbook->add_format();
   $ft_yellow->set_bg_color('yellow');
   $ft_yellow->set_underline();
   $ft_yellow->set_color(39);
   $ft_yellow->set_border('1');
   $ft_yellow->set_valign('vcenter');
my $ft_blue = $workbook->add_format();
   $ft_blue->set_bg_color(12);
   $ft_blue->set_underline();
   $ft_blue->set_color(39);
   $ft_blue->set_border('1');
   $ft_blue->set_valign('vcenter');
my $ft_green = $workbook->add_format();
   $ft_green->set_bg_color('#9BBB59');
   $ft_green->set_border('1');
   $ft_green->set_valign('vcenter');
   $ft_green->set_size(11);
   $ft_green->set_font('Calibri');
my $ft_green_2 = $workbook->add_format();
   $ft_green_2->set_bg_color('#92D050');
   $ft_green_2->set_border('1');
   $ft_green_2->set_valign('vcenter');
   $ft_green_2->set_size(11);
   $ft_green_2->set_font('Calibri');
my $ft_ogreen = $workbook->add_format();
   $ft_ogreen->set_bg_color('#D8E4BC');
   $ft_ogreen->set_border('1');
   $ft_ogreen->set_valign('vcenter');
   $ft_ogreen->set_size(11);
   $ft_ogreen->set_font('Calibri');
my $ft_gray = $workbook->add_format();
   $ft_gray->set_bg_color('gray');
   $ft_gray->set_color(39);
   $ft_gray->set_border('1');
   $ft_gray->set_valign('vcenter');
   $ft_gray->set_size(11);
   $ft_gray->set_font('Calibri');
my $ft_white = $workbook->add_format();
   $ft_white->set_bg_color(9);
   $ft_white->set_valign('vcenter');
   $ft_white->set_border('1');
my $ft_link = $workbook->add_format();
   $ft_link->set_underline();
   $ft_link->set_color(39);
my $ft_link_border = $workbook->add_format();
   $ft_link_border->set_underline();
   $ft_link_border->set_color(39);
   $ft_link_border->set_border();
my $ft_Courier_11_border = $workbook->add_format();
   $ft_Courier_11_border->set_border('1');
   $ft_Courier_11_border->set_size(11);
   $ft_Courier_11_border->set_font('Courier');


#--------------------------------------
my %type_of_pattern;
#--------------------------------------
create_cover_sheet ($workbook);
#create_top_sheet ($workbook);
create_outline_sheet ($workbook);
#--------------------------------------

my $sheet_num = 0;

#=========== Summay sheet =============
foreach my $line_TM (`cat $lst_LIST_ALL`){ # START foreach (1)
   chomp ($line_TM);
   @PAT_lst = split (/ /,$line_TM);
   my $NEW_PAT = "$PAT_lst[0]";
      $NEW_PAT =~ s/\.s//g;
      $NEW_PAT =~ s/\.asm//g;
      $NEW_PAT =~ s/\.c//g;
      $NEW_PAT =~ s/\.S//g;
   #my $sheet_name = $sheet_num."_".$NEW_PAT;
   @sheet_name_tmp_split = split ('/',$NEW_PAT);

   my $sheet_name = $sheet_num."_"."$sheet_name_tmp_split[-1]";

   #create_sheet($workbook, $NEW_PAT, $line_TM);
   $sheet_name = substr($sheet_name,0,30);
   $sheet_name =~ s/common\///g;
   $sheet_name =~ s/\//__/g;

   print "$sheet_name\n";
   #create_sheet($workbook, $sheet_name, $line_TM);
   create_sheet($workbook, $NEW_PAT, $line_TM, $sheet_name);

   $sheet_num = $sheet_num + 1;

} # END foreach (1)


#=========== Insert additional file ==============
###if (-e $lst_COMMON ){
###  foreach my $line_TM (`cat $lst_COMMON`){ # START foreach (1)
###      chomp ($line_TM);
###      @PAT_lst = split (/ /,$line_TM);
###      my $NEW_PAT = "$PAT_lst[0]";
###
###      my $sheet_name = $sheet_num."_".$NEW_PAT;
###
###      $sheet_name = substr($sheet_name,0,30);
###      $sheet_name =~ s/common\///g;
###      $sheet_name =~ s/\//__/g;
###
###      print "$sheet_name\n";
###
###      print "\n\nLine: $line_TM\n";
###      create_sheet($workbook, $NEW_PAT, $line_TM, $sheet_name);
###
###      $sheet_num = $sheet_num + 1;
###  
###  } # END foreach (1)
###
###}

#-----------------------------------------------------------------------------------------------------
sub draw_tb {
my @arguments = @_;
my  $worksheet  =  $arguments[0];
my  $max_row    =  $arguments[1];
my  $min_row    =  $arguments[2];
my  $max_col    =  $arguments[3];


while ($min_row < $max_row) {
   my  $min_col    =  $arguments[4];

   while ($min_col < $max_col + 1) {
      $worksheet->write($min_row,$min_col,"", $ft_Calibri_11_border);
      $min_col++;
   }

   $min_row++;
}

}


#=======  Find max number  ============
sub max_num {
   my ($num_1,$num_2,$num_3) = @_;
   my $max = 0;
   if ($max < $num_1){ $max = $num_1 }
   if ($max < $num_2){ $max = $num_2 }
   if ($max < $num_3){ $max = $num_3 }
   return $max;
}
#=======  Optimize name    ============
sub name_opt {
   my ($num,$file_name) = @_;
   my $name = `echo "$num\_$file_name" | sed -n 's/\\(.\\{30\\}\\).*/\\1/p'`;
   chomp ($name);
   return $name;
}



#--------------------------------------------------------------------------------------------------------
sub create_sheet {
my @arguments = @_;
my  $workbook      =  $arguments[0];
my  $sheet_name_tmp = $arguments[3];
#print "Sheet name: $sheet_name_tmp\n";
$sheet_name_tmp =~ s/common\///g;

#print "Sheet name: $sheet_name_tmp\n";
my $pattern_name = "";
if ($arguments[1] =~ /common\//) {
   $pattern_name  =  "common";
   print "TM name: $pattern_name\n";
} else {
   $pattern_name = $arguments[1];
   print "TM name: $pattern_name\n";

}

my  $line_TM       =  $arguments[2];
my @PAT_lst = split (/ /,$line_TM);

my $first_row = 80;
my $current_row = $first_row;

my $sheet_new = $workbook->add_worksheet("$sheet_name_tmp");

$sheet_new->set_column('B:B', 20);
$sheet_new->set_column('C:C', 20);
$sheet_new->set_column('D:D', 70);
$sheet_new->set_column('E:E', 70);
$sheet_new->set_column('F:F', 30);
$sheet_new->set_column('G:G', 30);
$sheet_new->set_column('H:H', 50);
$sheet_new->set_column('I:I', 30);

#$sheet_new->write(A1,'{PRODUCT NAME} {INSTANCE NAME (MODULE NAME)} Test pattern description - Test pattern name', $ft_Arial_20_bold); 
$sheet_new->write_url(0,0,  "internal:'Outline'!A1", "Go to \"Outline\" sheet", $ft_link);

#$sheet_new->write(A5,"Legend:",$ft_Calibri_11_bold);
#$sheet_new->write(B7,"Modify",$ft_mod);
#$sheet_new->write(B8,"New",$ft_new);
#$sheet_new->write(B9,"Delete",$ft_del);
#$sheet_new->write(B10,"Original",$ft_org);

$sheet_new->write(A3,"Verication Pattern Name",$ft_Calibri_11_bold);

$sheet_new->write(A7,"New verification pattern information (SVN repository, version,  or File path of original veification pattern, etc.)",$ft_Calibri_11_bold);

$sheet_new->write(A10,"Verification Target products",$ft_Calibri_11_bold);

$sheet_new->write(A13,"Overview",$ft_Calibri_11_bold);

$sheet_new->write(A9,"Port usage",$ft_Calibri_11_bold);
&draw_tb($sheet_new,15,10,3,1);
$sheet_new->write(B11,"Port",$ft_Calibri_11_bold_border);
$sheet_new->write(C11,"Direction",$ft_Calibri_11_bold_border);
$sheet_new->write(D11,"Usage",$ft_Calibri_11_bold_border);

$sheet_new->write(A17,"Additional Macro (Not default of simulation environment)",$ft_Calibri_11_bold);
&draw_tb($sheet_new,23,18,3,1);
$sheet_new->write(B19,"Macro",$ft_Calibri_11_bold_border);
$sheet_new->write(C19,"Content",$ft_Calibri_11_bold_border);
$sheet_new->write(D19,"Purpose",$ft_Calibri_11_bold_border);

$sheet_new->write(A25,"Environment Edit",$ft_Calibri_11_bold);
&draw_tb($sheet_new,33,26,3,1);
$sheet_new->write(B27,"Item/File",$ft_Calibri_11_bold_border);
$sheet_new->write(C27,"Content",$ft_Calibri_11_bold_border);
$sheet_new->write(D27,"Reason of editing",$ft_Calibri_11_bold_border);

$sheet_new->write(A35,"Connection model",$ft_Calibri_11_bold);
$sheet_new->write(A49,"Test Flow",$ft_Calibri_11_bold);
#$sheet_new->write(B51,"Before",$ft_Calibri_11_bold);
#$sheet_new->write(E51,"After",$ft_Calibri_11_bold);

$sheet_new->write(A78,"Test pattern content",$ft_Calibri_11_bold);
$sheet_new->write(B80,"Verification Item",$ft_Calibri_11_bold_border_2);
$sheet_new->write(C80,"Source File",$ft_Calibri_11_bold_border_2);
$sheet_new->write(D80,"Content",$ft_Calibri_11_bold_border_2);
$sheet_new->write(E80,"Description",$ft_Calibri_11_bold_border_2);
#$sheet_new->write(F100,"Modification/Reason",$ft_Calibri_11_bold_border_2);
$sheet_new->write(F80,"Related step in test flow",$ft_Calibri_11_bold_border_2);



foreach my $file_PAT (@PAT_lst){ # START foreach (2)
   #print "FILEL: $file_PAT\n";
   #my $name_PAT = `basename $file_PAT`;
   my $name_PAT_tmp = $file_PAT;
      $name_PAT_tmp =~ s/common\///g;
   @name_PAT_tmp_split = split ('/',$name_PAT_tmp);
   my $name_PAT = "$name_PAT_tmp_split[-1]";
#    chomp ($name_PAT);
   $sheet_new->merge_range($current_row,1,$current_row,5,'',$ft_green_2);
   $current_row++;
   $sheet_new->write($current_row, 1, "", $ft_Calibri_11_border);
   $sheet_new->write($current_row, 2, "$name_PAT", $ft_Calibri_11_border);
   $sheet_new->write($current_row, 3, "", $ft_Calibri_11_border);
   $sheet_new->write($current_row, 4, "", $ft_Calibri_11_border);
   $sheet_new->write($current_row, 5, "", $ft_Calibri_11_border);
   #$sheet_new->write($current_row, 6, "", $ft_Calibri_11_border);
   $current_row++;

   foreach my $line (`cat $NEW/$pattern_name/$name_PAT`){ #foreach vimdiff
         chomp ($line);
         $sheet_new->write($current_row, 1, "", $ft_Calibri_11_border);
         $sheet_new->write($current_row, 2, "", $ft_Calibri_11_border);
         $sheet_new->write($current_row, 3, "$line", $ft_Courier_11_border);
         $sheet_new->write($current_row, 4, "", $ft_Calibri_11_border);
         $sheet_new->write($current_row, 5, "", $ft_Calibri_11_border);
         #$sheet_new->write($current_row, 6, "", $ft_Calibri_11_border);
         $current_row++;
   }  

}


#  #### Waveform
#
#  $current_row++;
#  $current_row++;
#
#  $sheet_new->write($current_row,0,"Waveform check result",$ft_Calibri_11_bold);
#
#  $current_row++;
#  $current_row++;
#
#  $sheet_new->write($current_row,1, "Verification item", $ft_Calibri_11_bold_border);
#  $sheet_new->write($current_row,2, "", $ft_Calibri_11_bold_border);
#  $sheet_new->write($current_row,3, "Waveform \(Include explanation\/some note on waveform\)", $ft_Calibri_11_bold_border);
#  $sheet_new->write($current_row,4, "", $ft_Calibri_11_bold_border);
#  $sheet_new->write($current_row,5, "Waveform movement explanation", $ft_Calibri_11_bold_border);
#
$current_row++;
$current_row++;

#  $sheet_new->write($current_row,1, "", $ft_Calibri_11_border);
#  $sheet_new->write($current_row,2, "", $ft_Calibri_11_border);
#  $sheet_new->write($current_row,3, "", $ft_Calibri_11_border);
#  $sheet_new->write($current_row,4, "", $ft_Calibri_11_border);
#  $sheet_new->write($current_row,5, "", $ft_Calibri_11_border);
#
#  $current_row++;
#
#  $sheet_new->write($current_row,1, "", $ft_Calibri_11_border);
#  $sheet_new->write($current_row,2, "", $ft_Calibri_11_border);
#  $sheet_new->write($current_row,3, "", $ft_Calibri_11_border);
#  $sheet_new->write($current_row,4, "", $ft_Calibri_11_border);
#  $sheet_new->write($current_row,5, "", $ft_Calibri_11_border);

#  $current_row++;
$sheet_new->write_url($current_row,0,  "internal:$sheet_name_tmp!A1", "Go to top line", $ft_link);
$current_row++;
#$sheet_new->write_url($current_row,0,  "internal:'Cover'!A1", "Go to \"Cover\" sheet", $ft_link);





}



#----------- COVER SHEET   ------------
sub create_cover_sheet {
my @arguments = @_;
my $workbook = $arguments[0];

my $cover = $workbook-> add_worksheet("Cover");   #Create sheet Cover

$cover->set_column('B:B',25);
$cover->set_column('C:C',25);
$cover->set_column('D:D',25);
$cover->set_column('E:E',25);
$cover->set_column('F:F',25);
$cover->set_column('G:G',25);

#$cover->write(B2,"Document Number", $ft_formal_border);

$cover->write(B3,"", $ft_formal_top);
$cover->write(C3,"", $ft_formal_top);
$cover->write(D3,"", $ft_formal_top);
$cover->write(E3,"", $ft_formal_top);
$cover->write(F3,"", $ft_formal_top);
$cover->write(G3,"", $ft_formal_top);

$cover->write(B12,"", $ft_formal_top);
$cover->write(C12,"", $ft_formal_top);
$cover->write(D12,"", $ft_formal_top);
$cover->write(E12,"", $ft_formal_top);
$cover->write(F12,"", $ft_formal_top);
$cover->write(G12,"", $ft_formal_top);


#$cover->merge_range(1,2,1,6,'',$ft_merge_formal);
$cover->merge_range(3,1,3,6,'FAMILY/PRODUCT NAME',$ft_merge_horizontal);
$cover->merge_range(5,1,5,6,'INSTANCE NAME (MODULE NAME)',$ft_merge_horizontal);
$cover->merge_range(7,1,7,6,'MODULE PATTERN DESCRIPTION',$ft_merge_horizontal);
$cover->merge_range(9,1,9,6,'RENESAS',$ft_merge_horizontal_small);

$cover->write(B13,"Revision history", $ft_formal_bold);

$cover->write(B14,"Version", $ft_formal_border);
$cover->write(C14,"Content", $ft_formal_border);
$cover->write(D14,"Creator/date", $ft_formal_border);
$cover->write(E14,"Examiner/date", $ft_formal_border);
$cover->write(F14,"Approver/date", $ft_formal_border);
$cover->write(G14,"Remark", $ft_formal_border);

$cover->write(B15,"", $ft_formal_border);
$cover->write(C15,"", $ft_formal_border);
$cover->write(D15,"", $ft_formal_border);
$cover->write(E15,"", $ft_formal_border);
$cover->write(F15,"", $ft_formal_border);
$cover->write(G15,"", $ft_formal_border);

$cover->write(B16,"", $ft_formal_border);
$cover->write(C16,"", $ft_formal_border);
$cover->write(D16,"", $ft_formal_border);
$cover->write(E16,"", $ft_formal_border);
$cover->write(F16,"", $ft_formal_border);
$cover->write(G16,"", $ft_formal_border);

$cover->write(B17,"", $ft_formal_border);
$cover->write(C17,"", $ft_formal_border);
$cover->write(D17,"", $ft_formal_border);
$cover->write(E17,"", $ft_formal_border);
$cover->write(F17,"", $ft_formal_border);
$cover->write(G17,"", $ft_formal_border);
}



#----------- TOP SHEET   ------------
sub create_top_sheet{
my @arguments = @_;
my $workbook = $arguments[0];
my $pattern_count   = 1;
my $max_row_top_sheet = 14; 
my $top = $workbook-> add_worksheet("Top");   #Create sheet Cover

$top->write(A1,'{PRODUCT NAME} {INSTANCE NAME (MODULE NAME)} Test pattern description - Test pattern name', $ft_Arial_20_bold); 

$top->write(A3,"Legend:",$ft_Calibri_11_bold);
$top->write(B5,"Modify",$ft_mod);
$top->write(B6,"New",$ft_new);
$top->write(B7,"Delete",$ft_del);
$top->write(B8,"Original",$ft_org);


$top->write(A10,"Table of content",$ft_Calibri_11_bold);
$top->write(B12,"1",$ft_Calibri_11_bold);
$top->write(B13,"2",$ft_Calibri_11_bold);
$top->write(B14,"3",$ft_Calibri_11_bold);
$top->write_url(11,2,  "internal:'Top'!A1", "Top", $ft_link);
$top->write_url(12,2,  "internal:'Outline'!A1", "Outline", $ft_link);
$top->write(13,2,  "Description of each pattern", $ft_link);


my $pat_num = 0;

foreach my $line_TM (`cat $lst_LIST_ALL`){ # START foreach (1)
      chomp ($line_TM);
      @PAT_lst = split (/ /,$line_TM);
      my $NEW_PAT = "$PAT_lst[0]";
         $NEW_PAT =~ s/\.s//g;
         $NEW_PAT =~ s/\.asm//g;
         $NEW_PAT =~ s/\.c//g;
         $NEW_PAT =~ s/\.S//g;

      my $pat_link = $pat_num."_".$NEW_PAT;
      $pat_link = substr($pat_link,0,30);
      $pat_link =~ s/common\///g;
      $pat_link =~ s/\//__/g;

      $top->write($max_row_top_sheet,2,"3_$pattern_count",$ft_Calibri_11_bold);
      $top->write_url($max_row_top_sheet,3,  "internal:$pat_link!A1", $NEW_PAT, $ft_link);
      $max_row_top_sheet++;
      $pattern_count++;
      $pat_num++;
   
}


$top->write($max_row_top_sheet,1,"4",$ft_Calibri_11_bold);
$top->write($max_row_top_sheet,2,"Common",$ft_link);
$max_row_top_sheet++;
$pattern_count = 1;

if (-e $lst_COMMON ){
   foreach my $line_TM (`cat $lst_COMMON`){ # START foreach (1)
      chomp ($line_TM);
      my @PAT_lst = split (/ /,$line_TM);
      my $NEW_PAT = "$PAT_lst[0]";
         $NEW_PAT =~ s/common\///g;
         #$NEW_PAT =~ s/\.s//g;
         #$NEW_PAT =~ s/\.asm//g;
         #$NEW_PAT =~ s/\.c//g;
         #$NEW_PAT =~ s/\.S//g;

      my $pat_link = $pat_num."_".$NEW_PAT;
      $pat_link = substr($pat_link,0,30);
      $pat_link =~ s/common\///g;
      $pat_link =~ s/\//__/g;


      $top->write($max_row_top_sheet,2,"4_$pattern_count",$ft_Calibri_11_bold);
      $top->write_url($max_row_top_sheet,3,  "internal:$pat_link!A1", $NEW_PAT, $ft_link);
      $max_row_top_sheet++;
      $pattern_count++;
      $pat_num++;
   }
}
$top->write_url($max_row_top_sheet,0,  "internal:'Top'!A1", "Go to top line", $ft_link);


}



#------------------------------------------------------------------------------------------------------------------------------------
sub create_outline_sheet{
my @arguments = @_;
my $workbook = $arguments[0];

#my $max_row_top_sheet = 24; 
my $max_row_top_sheet = 18; 

my $head_of_summary = 2; 
my $head_of_related_document = 7; 
my $head_of_test_pattern_list = 13; 

my $outline = $workbook-> add_worksheet("Outline");   #Create sheet Cover

$outline->set_column('B:B', 30);
$outline->set_column('C:C', 30);
$outline->set_column('E:E', 20);
$outline->set_column('F:F', 20);
$outline->set_column('G:G', 30);
$outline->set_column('H:H', 30);
$outline->set_column('I:I', 30);
$outline->set_column('J:J', 20);
$outline->set_column('K:K', 50);
$outline->set_column('L:L', 50);
$outline->set_column('M:M', 50);


#$outline->write(A1,'{PRODUCT NAME} {INSTANCE NAME (MODULE NAME)} Test pattern description - Test pattern name', $ft_Arial_20_bold); 
#$outline->write_url(2,0,  "internal:'Top'!A1", "Go to \"Top\" sheet", $ft_link);

$outline->write_url(0,0,  "internal:'Cover'!A1", "Go to \"Cover\" sheet", $ft_link);

###$outline->write(A5,"Legend:",$ft_Calibri_11_bold);
###$outline->write(B6,"Total",$ft_Calibri_11_border);
###$outline->write(B7,"Modify",$ft_mod);
###$outline->write(B8,"New",$ft_new);
###$outline->write(B9,"Delete",$ft_del);
###$outline->write(B10,"Original",$ft_org);

###$outline->write(C6,'=COUNTIF($D$25:$D$30000,"<>")-C9',$ft_Calibri_11_border);
###$outline->write(C7,'=COUNTIFS($D$25:$D30000,B7,$A$25:$A30000,"DONE")',$ft_mod);
###$outline->write(C8,'=COUNTIFS($D$25:$D30000,B8,$A$25:$A30000,"DONE")',$ft_new);
###$outline->write(C9,'=COUNTIFS($D$25:$D30000,B9,$A$25:$A30000,"DONE")',$ft_del);
###$outline->write(C10,'=COUNTIFS($D$25:$D30000,B10,$A$25:$A30000,"DONE")',$ft_org);

$outline->write($head_of_summary,0,"Summary:",$ft_Calibri_11_bold);

$outline->write($head_of_summary+1,1,"Total",$ft_Calibri_11_border);
$outline->write($head_of_summary+2,1,"DONE",$ft_Calibri_11_border);
$outline->write($head_of_summary+3,1,"Remain",$ft_Calibri_11_border);

$outline->write($head_of_summary+1,2,'=COUNTA($B$19:$B$30000)',$ft_Calibri_11_border);
$outline->write($head_of_summary+2,2,'=COUNTIF(A19:A30000,$B$5)',$ft_Calibri_11_border);
$outline->write($head_of_summary+3,2,'=C4-C5',$ft_Calibri_11_border);

$outline->write($head_of_summary+1,4,'<- Do not move the cells in the left table! They are referred to by external tool.',$ft_Calibri_11_red);
$outline->write($head_of_summary+2,4,'<- Do not move the cells in the left table! They are referred to by external tool.',$ft_Calibri_11_red);
$outline->write($head_of_summary+3,4,'<- Do not move the cells in the left table! They are referred to by external tool.',$ft_Calibri_11_red);

$outline->write($head_of_related_document,0,"Related document",$ft_Calibri_11_bold);

$outline->write($head_of_related_document+1,1,"Target Spec",$ft_Calibri_11_border);
$outline->write($head_of_related_document+2,1,"Implementation spec",$ft_Calibri_11_border);
$outline->write($head_of_related_document+3,1,"Verification item list",$ft_Calibri_11_border);
$outline->write($head_of_related_document+4,1,"Verification policy",$ft_Calibri_11_border);

$outline->merge_range($head_of_related_document+1,2,$head_of_related_document+1,5,'Hyperlink to target spec',$ft_merge_blue);
$outline->merge_range($head_of_related_document+2,2,$head_of_related_document+2,5,'Hyperlink to implementation spec',$ft_merge_blue);
$outline->merge_range($head_of_related_document+3,2,$head_of_related_document+3,5,'Hyperlink to verification item list',$ft_merge_blue);
$outline->merge_range($head_of_related_document+4,2,$head_of_related_document+4,5,'Hyperlink to verification policy',$ft_merge_blue);

$outline->write($head_of_test_pattern_list,0,"Test pattern list",$ft_Calibri_11_bold);

$outline->write($head_of_test_pattern_list+1,0,'->(Don\'t move!)',$ft_Calibri_11_red);
$outline->write($head_of_test_pattern_list+2,0,'Status',$ft_Calibri_11_bold);

$outline->merge_range($head_of_test_pattern_list+2,1,$head_of_test_pattern_list+4,1,'Test pattern name',$ft_tittle);
$outline->merge_range($head_of_test_pattern_list+2,2,$head_of_test_pattern_list+4,2,'Test pattern overview',$ft_tittle);
#$outline->merge_range($head_of_test_pattern_list+2,3,$head_of_test_pattern_list+4,3,'New/ Modify/ Original/ Delete',$ft_tittle);
$outline->merge_range($head_of_test_pattern_list+2,3,$head_of_test_pattern_list+4,3,'Pattern Group',$ft_tittle);
$outline->merge_range($head_of_test_pattern_list+2,4,$head_of_test_pattern_list+4,4,'Option (fasm)',$ft_tittle);
$outline->merge_range($head_of_test_pattern_list+2,5,$head_of_test_pattern_list+4,5,'Option (fsim)',$ft_tittle);
$outline->merge_range($head_of_test_pattern_list+2,6,$head_of_test_pattern_list+4,6,'ASM/C source (.asm/...)',$ft_tittle);
$outline->merge_range($head_of_test_pattern_list+2,7,$head_of_test_pattern_list+4,7,'Stimulus source (.v/...)',$ft_tittle);
$outline->merge_range($head_of_test_pattern_list+2,8,$head_of_test_pattern_list+4,8,'Assertion source (.sv/...)',$ft_tittle);

#$outline->write($head_of_test_pattern_list+2,9,'Environment edit',$ft_tittle);
$outline->merge_range($head_of_test_pattern_list+2,9,$head_of_test_pattern_list+4,9,"Environment edit\nYes/No",$ft_tittle);

$outline->merge_range($head_of_test_pattern_list+2,10,$head_of_test_pattern_list+2,11,'Pass condition',$ft_tittle);

$outline->write($head_of_test_pattern_list+3,10,'Simulation result :"test_bench complete [OK]" and "Normal End"',$ft_green);
$outline->write($head_of_test_pattern_list+4,10,'Yes/No',$ft_tittle);

$outline->write($head_of_test_pattern_list+3,11,'Assertion ATTEMPTS = REAL SUCCESSES =! 0',$ft_green);
$outline->write($head_of_test_pattern_list+4,11,'Yes/No',$ft_tittle);

#$outline->write($head_of_test_pattern_list+2,12,'Note',$ft_tittle);
$outline->merge_range($head_of_test_pattern_list+2,12,$head_of_test_pattern_list+4,12,'Note',$ft_tittle);
#  $outline->write($head_of_test_pattern_list+4,12,'',$ft_ogreen);
#  $outline->write($head_of_test_pattern_list+5,12,'Yes/No',$ft_Calibri_11_bold_border);


#my $min_row = 24;
my $min_row = 18;

my $num_of_patterns = `cat $lst_LIST_ALL | wc -l`; 
my $max_row = $min_row + $num_of_patterns;
&draw_tb($outline,$max_row, $min_row,12,1);

my $pat_num = 0;

foreach my $line_TM (`cat $lst_LIST_ALL`){ # START foreach (1)
      chomp ($line_TM);
      @PAT_lst = split (/ /,$line_TM);
      my $NEW_PAT_tmp = "$PAT_lst[0]";
         $NEW_PAT_tmp =~ s/\.s//g;
         $NEW_PAT_tmp =~ s/\.asm//g;
         $NEW_PAT_tmp =~ s/\.c//g;
         $NEW_PAT_tmp =~ s/\.S//g;

      @NEW_PAT_tmp_split = split ('/',$NEW_PAT_tmp);
      my $NEW_PAT = "$NEW_PAT_tmp_split[-1]";

      my $pat_link = $pat_num."_".$NEW_PAT;
      $pat_link = substr($pat_link,0,30);
      $pat_link =~ s/common\///g;
      $pat_link =~ s/\//__/g;

      $outline->write_url($max_row_top_sheet,1,  "internal:$pat_link!A1", $NEW_PAT, $ft_link_border);

      $pat_num = $pat_num + 1;

      my $s_same = 0;
      my $s_diff = 0;
      my $s_new = 0;
      my $v_same = 0;
      my $v_diff = 0;
      my $v_new = 0;
      my $sv_same = 0;
      my $sv_diff = 0;
      my $sv_new = 0;

      foreach my $file_PAT (@PAT_lst){ # START foreach (2)
         #my $name_PAT = `basename $file_PAT`;
         my $name_PAT_tmp = `basename $file_PAT`;
         @name_PAT_tmp_split = split ('/',$name_PAT_tmp);
         my $name_PAT = "$name_PAT_tmp_split[-1]";

         chomp ($name_PAT);
         if (($name_PAT =~ /\.s$/) | ($name_PAT =~ /\.asm$/) | ($name_PAT =~ /\.c$/) | ($name_PAT =~ /\.S$/) )  {
            ($s_same, $s_diff, $s_new) = pattern_chk($NEW_PAT, $name_PAT); 
            $outline->write ($max_row_top_sheet,6,$name_PAT, $ft_Calibri_11_border);
         }

         if ($name_PAT =~ /\.sv$/) {
            ($v_same, $v_diff, $v_new) = pattern_chk($NEW_PAT, $name_PAT); 
            $outline->write ($max_row_top_sheet,8,$name_PAT, $ft_Calibri_11_border);
         }

         if ($name_PAT =~ /\.v$/) {
            ($sv_same, $sv_diff, $sv_new) = pattern_chk($NEW_PAT, $name_PAT); 
            $outline->write ($max_row_top_sheet,7,$name_PAT, $ft_Calibri_11_border);
         }
   } # END foreach (2)


   #if ($s_same | $v_same |$sv_same) {
   #   $outline->write ($max_row_top_sheet,3,"Original", $ft_Calibri_11_border);
   #} 

   #if ($s_diff | $v_diff |$sv_diff) {
   #   $outline->write ($max_row_top_sheet,3,"Modify", $ft_Calibri_11_border);
   #} 

   #if ($s_new | $v_new |$sv_new) {
   #   $outline->write ($max_row_top_sheet,3,"New", $ft_Calibri_11_border);
   #} 

   $outline->write ($max_row_top_sheet,3,"", $ft_Calibri_11_border);

$max_row_top_sheet++;
   
}


$max_row_top_sheet++;
$outline->write_url($max_row_top_sheet,0,  "internal:'Outline'!A1", "Go to top line", $ft_link);
$max_row_top_sheet++;
$outline->write_url($max_row_top_sheet,0,  "internal:'Cover'!A1", "Go to \"Cover\" sheet", $ft_link);

}


sub pattern_chk {
            my ($folder_name,$file_name) = @_;
            my $pattern_same = 0;
            my $pattern_diff  = 0;
            my $pattern_new   = 0;

            if (-e "$OLD\/$folder_name\/$file_name"){
               `rm -rf $lst_tem_tinh`;
               `sdiff -b -B -l -t -s --ignore-blank-lines --ignore-all-space -w 1000 $OLD/$folder_name/$file_name $NEW/$folder_name/$file_name > $lst_tem_tinh`;
               my $word = `cat ./$lst_tem_tinh | wc -l`;
               if ($word != 0){ $pattern_same = 0;    $pattern_diff  = 1;    $pattern_new   = 0; }
               if ($word == 0){ $pattern_same = 1;    $pattern_diff  = 0;    $pattern_new   = 0; }
            } else { $pattern_same = 0;    $pattern_diff  = 0;    $pattern_new   = 1; }

            return ($pattern_same,$pattern_diff,$pattern_new);

}

my $time_end = date;
print "\n>> Completed!!!\n";
print "--\n";
print "Pattern description file: $excel_name\n";
print "-------------------------------------------------\n";

