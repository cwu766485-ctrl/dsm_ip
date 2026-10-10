"""Review selected XPM directional bins against actual installed connections."""
import argparse,hashlib,json,re
from pathlib import Path
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--ledger',type=Path,required=True);ap.add_argument('--xpm-root',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);args=ap.parse_args()
    fifo=args.xpm_root/'data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv';mem=args.xpm_root/'data/ip/xpm/xpm_memory/hdl/xpm_memory.sv'
    cdc=args.xpm_root/'data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv'
    f=fifo.read_text();m=mem.read_text()
    assert '.dinb           ({READ_DATA_WIDTH{1\'b0}}' in f
    assert 'assign douta = {READ_DATA_WIDTH_A{1\'b0}}' in m
    assert 'if(`DISABLE_SYNTH_TEMPL) begin : gen_blk_box' in m
    rows=json.loads(args.ledger.read_text())['records'];review=[]
    for r in rows:
        if r['status']!='OPEN_VENDOR':continue
        reason=None
        if r['metric'] in ('line','branch','cond'):
            raw=r['raw'];inst=r['instance'];line=int(str(raw['line']).split('.')[0])
            # Initial parameter checks have no runtime inputs. Their exact
            # predicate/statement is retained with the record; other lines
            # (including startup reset and runtime warnings) remain OPEN.
            ranges=(302,1061) if 'xpm_memory_base_inst' in inst else (316,449) if inst.endswith('xpm_fifo_base_inst') else (2294,2305) if inst.endswith('u_xpm_fifo_async') else (1074,1107) if inst.endswith(('wrst_rd_inst','rrst_wr_inst')) else (303,345) if inst.endswith(('wr_pntr_cdc_inst','rd_pntr_cdc_inst','wr_pntr_cdc_dc_inst','rd_pntr_cdc_dc_inst')) else None
            if ranges and ranges[0]<line<ranges[1]:
                reason='Elaboration-only configuration DRC, exact frozen legal parameters. Baseline completed this initial block without any XPM DRC error; no runtime stimulus can change its predicate. Exact statement retained in raw ledger.'
            if 'xpm_memory_base_inst' in inst and line in (1200,1201):
                reason='MEMORY_INIT_FILE=none / USE_MEM_INIT=0 selects NO_MEMORY_INIT; external-file initialization path disabled.'
            if 'xpm_memory_base_inst' in inst and line in (2674,2679,2680,3085,3088):
                reason='FWFT RD_LATENCY=2 and WRITE_MODE_B=2(no_change): only the final single output-pipeline reset-value initialization is selected; the alternate read-register/earlier-stage initialization is absent.'
            if 'xpm_memory_base_inst' in inst and line in (3335,3340):
                reason='MESSAGE_CONTROL=0 makes its diagnostic warning/info initial arm false.'
            if 'xpm_memory_base_inst' in inst and (1257<=line<=1271):
                reason='Reset-value conversion is evaluated only at elaboration as a localparam; runtime code coverage cannot invoke this function.'
            if 'xpm_memory_base_inst' in inst and 1229<=line<=1251:
                reason='ASCII conversion is called only by frozen initialization/reset parameter conversion; no runtime port invokes it. MEMORY_INIT_PARAM/READ_RESET_VALUE are fixed legal strings.'
            if 'xpm_memory_base_inst' in inst and line in (3334,3336):
                reason='MESSAGE_CONTROL=0 selects neither diagnostic reporting branch; exact frozen constant.'
            if 'xpm_memory_base_inst' in inst and line==1193:
                reason='MEMORY_INIT_FILE=none and USE_MEM_INIT=0 make NO_MEMORY_INIT true; the external-file alternative is not enabled.'
            if 'xpm_memory_base_inst' in inst and line==2673:
                reason='Fixed READ_LATENCY_B=2/WRITE_MODE_B=no_change selects the single final-pipeline reset initialization; other initial macro arms are constant false.'
            if inst.endswith(('wrst_rd_inst','rrst_wr_inst')) and line==1147 or inst.endswith(('wr_pntr_cdc_inst','rd_pntr_cdc_inst','wr_pntr_cdc_dc_inst','rd_pntr_cdc_dc_inst')) and line==427:
                reason='Actual FIFO CDC instances use SIM_ASSERT_CHK=0; simulation-message enable branch cannot execute.'
            if line in (409,410,1132) and '.10' in str(raw['line']):
                assert '1\'b0' in (args.xpm_root/'data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv').read_text().splitlines()[line-1]
                reason='Exact XPM_XSRREG_INIT macro reset assignment: reset_p argument is literal 0; this synchronous-reset arm cannot execute. Global startup force/release is a different arm.'
            if inst.endswith(('rst_d1_inst','rst_d2_inst','next_state_d1_inst','empty_fwft_d1_inst','ge_fwft_d1_inst')) and line in (1939,1940):
                reason='This actual xpm_fifo_reg_bit instance has rst connected to literal 0; initialization and d_in update remain covered separately.'
            if inst.endswith('xpm_fifo_base_inst') and line in (1561,1566):
                reason='SIM_ASSERT_CHK=0 disables this initial optional warning; no runtime transaction changes the parameter.'
            if inst.endswith('xpm_fifo_base_inst') and line in (309,312):
                reason='Elaboration-only depth check: actual FIFO_WRITE_DEPTH=16 is exactly 2**clog2(16); non-power-of-two return arm disabled.'
            if 'xpm_memory_base_inst' in inst and line in (3540,3541,3584):
                reason='Actual SDPRAM ena=wea=ram_wr_en_i, so ena && !wea is false; A-read collision capture is inactive.'
            if 'xpm_memory_base_inst' in inst and line in (3552,3553,3590,3591,3592):
                reason='Actual SDPRAM web is literal 0, so enb && |web is false; B-write collision capture is inactive.'
            if 'xpm_memory_base_inst' in inst and line in (4198,4199,4200,4203,4204):
                reason='B-write collision capture wrb remains initialized 0 because web=0; this wrb-qualified collision arm cannot execute.'
            if 'xpm_memory_base_inst' in inst and line in (4176,4177):
                reason='Actual SDPRAM web=0 excludes this B-write collision force/flag assignment. Other enclosing read/write collision paths remain OPEN.'
            if 'xpm_memory_base_inst' in inst and line==4223:
                reason='Actual READ_LATENCY_B=2 excludes the READ_LATENCY_B==1 collision assignment; the latency-2 collision path remains OPEN.'
            if 'xpm_memory_base_inst' in inst and r['metric']=='cond':
                operand=raw['operand_bin'];expr=raw['expression']
                if (line==3571 and operand in ('0/1','1/0') or
                    line in (3582,3583) and operand=='1/1' or
                    line==3589 and operand in ('0/1','1/1') or
                    line in (3600,3601) and operand=='1/0'):
                    reason='Exact SDPRAM port relation: ena=wea and web=0. This operand combination contradicts that fixed connection; other runtime combinations remain included.'
                if line==4197 and (operand.startswith('1/') or operand=='1' or operand=='0/1/1'):
                    reason='B-write collision capture wrb and col_win_wr_b remain zero with web=0; exact operand vector demands one of those constant-zero terms high.'
            if reason:review.append({'bin_id':r['bin_id'],'instance':inst,'metric':r['metric'],'bin':r['bin'],'status':'CONFIGURATION_REVIEWED','reason':reason})
            continue
        if r['metric']!='toggle':continue
        name=r['bin'].split(':')[1].split('[')[0]
        if name in ('dinb','dinb_i'):reason='FIFO SDPRAM B write data is tied to zero; AUTO_SLEEP_TIME=0 direct dinb_i path.'
        if name=='douta':reason='MEMORY_TYPE=1 simple dual-port uses A write/B read; unused A-read output is explicitly zero.'
        if name in ('douta_bb','doutb_bb'):reason='Symmetric465-bit ports with full-word byte enable make MEM_PORT_ASYM_BWE=false; blackbox synthesis template absent and these wires undriven. Not a functional zero claim.'
        if name in ('prog_full','prog_empty','wr_data_count','rd_data_count','overflow','underflow','almost_full','almost_empty','data_valid','wr_ack'):
            reason='USE_ADV_FEATURES=0000 disables this named optional feature; vendor zero-select or disabled generate path drives constant/undriven state.'
        if name in ('sleep','injectsbiterr','injectdbiterr','rsta','regcea','web','injectsbiterrb','injectdbiterrb','injectsbiterra','injectdbiterra','dinb_i','web_i','regcea_i'):
            reason='Actual FIFO/memory instance connection ties this input low; no auto-sleep passthrough changes it.'
        if name in ('sbiterr','dbiterr','sbiterra','dbiterra','sbiterrb','dbiterrb','gen_rd_b.sbiterrb_i','gen_rd_b.dbiterrb_i'):
            reason='ECC_MODE=no_ecc: no ECC error status process generated, unused A-read status is explicitly zero and B status initialized zero.'
        if name=='ram_regce_pipe':reason='READ_MODE=fwft makes standard-read latency enable pipe absent; explicit zero assignment.'
        if name=='cnt_down' and r['instance'].endswith(('wrp_inst','rdp_inst','wrpp1_inst','wrpp2_inst','rdpp1_inst')):
            reason='Exact xpm_counter_updn instance connects cnt_down to literal 0; FIFO pointers increment only.'
        if name=='rst' and r['instance'].endswith(('rst_d1_inst','rst_d2_inst','next_state_d1_inst','empty_fwft_d1_inst','ge_fwft_d1_inst')):
            reason='Exact xpm_fifo_reg_bit instance reset connection is literal 0; normal data input remains active.'
        if name in ('wr_pntr_plus3','rd_pntr_plus2'):
            reason='EN_AF/EN_AE=0 selects explicit zero pointer-offset assignments (fifo lines501-523).'
        if name in ('wr_ack_i','ram_aempty_i','ram_afull_i','aempty_fwft_i','data_valid_fwft','data_valid_std','data_vld_std','overflow_i','underflow_i','prog_full_i','prog_empty_i'):
            reason='Named optional-feature state has no active update process because its exact USE_ADV_FEATURES enable is zero; retained declaration is constant or undriven.'
        if name in ('wr_pntr_plus1_pf','rd_pntr_wr_adj_inv_pf','diff_pntr_pf_q','diff_pntr_pf','ram_wr_en_pf_q','ram_rd_en_pf_q','wr_pntr_plus1_pf_carry','rd_pntr_wr_adj_pf_carry','diff_pntr_pe_reg1','diff_pntr_pe_reg2','diff_pntr_pe'):
            reason='EN_PF/EN_PE=0 removes the programmable-full/empty update generates for this symmetric independent-clock FIFO; retained optional wires/registers are undriven/constant.'
        if name in ('sleep_int_a','sleep_int_b','injectsbiterra_sim','injectdbiterra_sim','injectsbiterrb_sim','injectdbiterrb_sim'):
            reason='Actual sleep and error-injection ports are zero; AUTO_SLEEP_TIME=0 passthrough and sleep initialization/release keep these internal signals zero.'
        if name in ('gen_assert_coll_ww.wrb','gen_assert_coll_ww.web_cap','gen_assert_coll_ww.col_win_wr_b','gen_assert_coll_ww.addrb_cap'):
            reason='SDPRAM web=0 disables B-write capture; status remains initialized zero and unused captured address is undriven.'
        if name in ('gen_assert_coll_ww.rda_cap','gen_assert_coll_ww.col_win_rd_a','gen_assert_coll_ww.addra_rd_cap'):
            reason='SDPRAM ena=wea disables A-read capture; status stays zero and unused captured address is undriven.'
        if name=='gen_assert_coll_ww.async_clk_sym.wr_wr_col_asym_a':
            reason='B-write capture wrb stays zero, so B-write versus A collision flag is never asserted.'
        if name in ('wrp_gt_rdp_and_red','wrp_lt_rdp_and_red'):
            reason='Symmetric widths make WR_PNTR_WIDTH=RD_PNTR_WIDTH; neither asymmetric pointer reduction generate exists.'
        if name in ('write_allow','read_allow','write_only','read_only','ram_wr_en_pf','ram_rd_en_pf'):
            reason='COMMON_CLOCK=0/RELATED_CLOCKS=0 disables gen_pf_cc; these common-clock-only wires have no driver.'
        if name in ('write_only_q','read_only_q'):
            reason='COMMON_CLOCK=0 disables gen_pntr_flags_cc and EN_PE=0 removes its update process; retained registers have no driver.'
        if name in ('ram_empty_i_d1','fe_of_empty'):
            reason='These signals are assigned only in READ_MODE=2 gen_fwft_ge_ll; actual READ_MODE=1 removes that generate. Retained declarations are constant/undriven.'
        if name in ('wr_en_i','rd_rst_d2','leaving_empty_fwft_fe','leaving_empty_fwft_re','le_fwft_re_wr','le_fwft_fe_wr'):
            assert len(re.findall(r'\b'+re.escape(name)+r'\b',f))==1
            reason='Vendor source declares this signal once and never references or assigns it; unused declaration, no functional update process.'
        if name in ('le_fwft_re','le_fwft_fe'):
            reason='Assigned only by READ_MODE=0 standard-read generate; actual READ_MODE=1 removes the driver and no other process references them.'
        if reason:review.append({'bin_id':r['bin_id'],'instance':r['instance'],'metric':r['metric'],'bin':r['bin'],'status':'CONFIGURATION_REVIEWED','reason':reason})
    args.out.mkdir(parents=True,exist_ok=False)
    # Prove the exact selected port types/values, not an ownership waiver.
    assert '.MEMORY_TYPE              (1' in f and '.AUTO_SLEEP_TIME          (0' in f
    assert '.BYTE_WRITE_WIDTH_A       (WRITE_DATA_WIDTH' in f and '.BYTE_WRITE_WIDTH_B       (READ_DATA_WIDTH' in f
    assert 'assign dinb_i = dinb;' in m
    result={'status':'PARTIAL_VENDOR_REVIEW','reviewed':review,'remaining_vendor_records':sum(r['status']=='OPEN_VENDOR' for r in rows)-len(review),'ledger_sha256':sha(args.ledger),'vendor_source_sha256':{str(p):sha(p) for p in (fifo,mem,cdc)},'scope':'SDPRAM MEMORY_TYPE=1, symmetric465-bit ports, no ECC/auto-sleep; no vendor ownership exclusion.'}
    (args.out/'manifest.json').write_text(json.dumps(result,indent=2)+'\n');print(len(review),result['remaining_vendor_records'])
if __name__=='__main__':main()
