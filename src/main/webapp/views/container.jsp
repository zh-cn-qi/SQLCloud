<%@ page language="java" contentType="text/html; charset=UTF-8" pageEncoding="UTF-8"%>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, shrink-to-fit=no">
<title>SQLCloud</title>
<link rel="stylesheet" href="https://cdn.bootcss.com/bootstrap/4.0.0/css/bootstrap.min.css" integrity="sha384-Gn5384xqQ1aoWXA+058RXPxPg6fy4IWvTNh0E263XmFcJlSAwiGgFAW/dAiS6JXm" crossorigin="anonymous">
<link rel="stylesheet" href="${path}/resources/css/glyphicons.css">
<link href="https://cdn.bootcss.com/zTree.v3/3.5.33/css/metroStyle/metroStyle.min.css" rel="stylesheet">

<script src="https://cdn.bootcss.com/jquery/2.2.4/jquery.min.js"></script>
<script type="text/javascript" src="${path}/resources/js/common.js"></script>
<script src="https://cdn.bootcss.com/zTree.v3/3.5.33/js/jquery.ztree.all.min.js"></script>
<script src="https://cdn.bootcss.com/jquery.serializeJSON/2.9.0/jquery.serializejson.min.js"></script>
<script src="https://cdn.bootcss.com/popper.js/1.12.9/umd/popper.min.js" integrity="sha384-ApNbgh9B+Y1QKtv3Rn7W3mgPxhU9K/ScQsAP7hUibX39j7fakFPskvXusvfa0b4Q" crossorigin="anonymous"></script>
<script src="https://cdn.bootcss.com/bootstrap/4.0.0/js/bootstrap.min.js" integrity="sha384-JZR6Spejh4U02d8jOt6vLEHfe/JQGiRRSQQxSfFWpi1MquVdAyjUar5+76PVCmYl" crossorigin="anonymous"></script>
	<!-- load ace -->
<script src="https://cdn.bootcss.com/ace/1.3.3/ace.js"></script>
<script src="https://cdn.bootcss.com/ace/1.3.3/ext-language_tools.js"></script>
<style type="text/css">
html,body{
	height: 100%;
}
.container-fluid,.main{
	height: 100%;
}
.col{
	padding: 0px;
}
.sql-toolbar{
	padding:0px;
	list-style: none;
	margin-bottom: 0px;
}
.sql-toolbar > li{
	display: inline-block;
}
.sql-toolbar > li label{
	padding:5px;
	margin: 0px;
}
.nav-link{
	padding: 0.1rem 0.5rem;
}
.table{
	width:auto;
	table-layout: fixed;
}
.table td,table th{
	text-align:left;
	overflow: hidden;
	white-space: nowrap;
	text-overflow: ellipsis;
	max-width: 300px;
	text-align: center;
}
</style>

<script type="text/javascript">
$(function(){
	//为String添加endsWith 方法
	String.prototype.endsWith = function(text){
		if(!text){
			return false;
		}
		if(text.length > this.length){
			return false;
		}
		return this.substr(this.length - text.length) === text;
	}
	var tableTree;
	//ztree setting
	var setting = {
		view:{
			showLine:false
		},
		data:{
			simpleData: {
				enable: true,
				idKey: "id",
				pIdKey: "pId",
				rootPId: -1
			},
			key:{
				title:"comment"
			}
		},
		callback: {
			beforeExpand: function(treeId, table){//展开表格加载列
				if($.isArray(table.children)){
					return true;
				}
				$.post("${path}/sql/columns",{tableName:table.id},function(data, status, xhr){
					if(data.code != 200){
						return false;
					}
					var columns = data.value.map(function(column){
						return {
							id:column.columnName,
							name:column.columnName + "("+column.columnType+")",
							comment:column.columnComment,
							nodeType:'column'
						};
					});
					tableTree.addNodes(table,columns);
				},"json");
			},
			onClick: function(event, treeId, treeNode){//单击插入编辑器光标处
				var cursor = editor.selection.getCursor();
				var upText = editor.session.getTextRange({start:{row:cursor.row,column:0},end:cursor}).toUpperCase().trim();
				var insertText = treeNode.id;
				if(upText){
					var digit = upText.charAt(upText.length-1);
					if(digit !== ',' && !upText.endsWith("SELECT") && !upText.endsWith("FROM")){
						insertText = ", " + insertText;
					}
				}
				editor.insert(insertText);
			},
			onRightClick:function(event, treeId, treeNode){//实现右键菜单
				if(treeNode.nodeType !== 'table'){
					return false;
				}
				
			}
		}
	};
	//加载表格
	$.post("${path}/sql/tables",{},function(data, status, xhr){
		var zNodes = data.value.map(function(item){
			return {
				pId:-1,
				id:item.tableName,
				name:item.tableName,
				nodeType:'table',
				isParent:true,
				comment:item.tableComment
			};
		});
		tableTree = $.fn.zTree.init($("#tableTree"), setting, zNodes);
	},"json");
	
	//执行SQL
	$("#executeSQL").on("click",function(){
		var range = editor.getSelectionRange();
		var sql = editor.session.getTextRange(range);
		//选中 > 光标 > 内容 
		if(!sql.replace(/^\s+/,'')){
			sql = editor.getTextCursorRange();
			if(!sql.replace(/^\s+/,'')){
				sql = editor.getValue();
			}
		}
		if(!sql.replace(/^\s+\n+\r+/,'')){
			return false;
		}
		var that = this;
		$(this).addClass("disabled").css("pointer-events","none");
		//转成大写，去除开头空格
		var sql = sql.toUpperCase().replace(/^\s+/,'');
		$.post('${path}/sql/execute',{sql:sql},function(data, status, xhr){
			emptyConsoleTabs();
			if(data.code == 200){
				var results = data.value;
				$.each(results,function(index, result){
					var console = newConsoleTab(index);
					if(result.type == 'query'){
						dynamicTable(result, console);
					}else if(result.type == 'update'){
						console.html("execute successfully. " + result.updateCount + " row updated");
					}else{
						//
					}
				});
			}else{
				newConsoleTab(0).html(data.message);
			}
			$(that).removeClass("disabled").css("pointer-events","auto");
		},"json");
	});
	
	//根据查询结果动态输出表格
	function dynamicTable(mapQuery, $console){
		var table = $("#tableModel").clone().attr("id",new Date().getTime());
		var columnRow = table.find("thead tr");
		columnRow.append("<th>序号</th>");
		$.each(mapQuery.columnNames,function(index,columnName){
			var aliasName = columnName.split('.')[2];
			columnRow.append("<th title='"+aliasName+"'>"+aliasName+"</th>");
		});
		var tbody = table.find("tbody");
		$.each(mapQuery.results,function(i,item){
			var dataRow = $("<tr></tr>");
			dataRow.append("<td>"+(i+1)+"</td>");
			$.each(mapQuery.columnNames,function(index,columnName){
				var content = item[columnName];
				if(content === true){
					content = "TRUE";
				}else if(content === false){
					content = "FALSE";
				}else if(content === null){
					content = "(Null)";
				}
				var popover = "";
				if(content != '(Null)' && content){
					popover = " data-toggle='popover' data-placement='top' data-content='" + content + "' ";
				}
				dataRow.append("<td" + popover + ">"+content+"</td>");
			});
			tbody.append(dataRow);
		});
		$console.html(table);
		//Enable popovers everywhere
		$('td[data-toggle="popover"]').popover();
		$("div.popover").css("pointer-events","none");
	}
	
	//新建一个控制台选项卡 并返回 ,index不可重复
	function newConsoleTab(index){
		var tabId = "console-" + (index+1);
		var tab = $('<li class="nav-item"><a class="nav-link '+(index == 0 ? 'active' : '')+' id="'+tabId+'-tab" data-toggle="tab" href="#'+tabId+'" role="tab">'+tabId+'</a></li>');
		var tabContent = $('<div class="tab-pane fade '+(index == 0 ? 'show active' : '')+'" id="'+tabId+'" role="tabpanel"></div>');
		
		$("#consoleTabs").append(tab);
		$("#consoleTabContent").append(tabContent);
		return tabContent;
	}
	//清空控制台选项卡 
	function emptyConsoleTabs(){
		$("#consoleTabs").empty();
		$("#consoleTabContent").empty();
		$('td[data-toggle="popover"]').popover('dispose');
	}

	//点击其它区域 隐藏 popover
	$(document).on("click",function(event){
		if(!$(event.target).hasClass("popover-body")){
			$('td[data-toggle="popover"]').popover('hide');
			if($(event.target).attr("data-toggle") == 'popover'){
				$(event.target).popover('toggle');
			}
		}
	});
});
</script>
</head>
<body>
	<div class="container-fluid">
	  <div class="row main">
	    <div class="col-3 bg-light" style="overflow: auto;">
	    	<ul id="tableTree" class="ztree"></ul>
	    </div>
  		<div class="col-9" style="padding: 0px 5px;">
  			<div class="container-fluid">
  				<div class="row" style="height: 60%;">
  					<div class="col" style="box-sizing: border-box;padding-top: 36px;padding-bottom: 5px;">
  					  <nav class="bg-light" style="position: absolute;left: 0px;top: 0px;width: 100%;">
	  					  <ul class="sql-toolbar">
	  					  	<li>
	  					  		<label id="executeSQL" class="btn bg-light text-primary">
	  					  			<span class="glyphicon glyphicon-play"></span> 
	  					  			<span style="vertical-align: middle;">运行</span>
	  					  		</label>
	  					  	</li>
	  					  </ul>
  					  </nav>
				      <%--textarea rows="" cols="" name="sql" style="width: 100%;height: 100%;resize: none;"></textarea>--%>
						<pre id="editor" class="ace_editor" style="height: 100%;width: 100%;"></pre>
				    </div>
  				</div>
  				<div class="row bg-white border-top border-secondary" style="height: 40%;">
  					<div class="col">
				      <ul class="nav nav-tabs" id="consoleTabs" role="tablist" style="position: absolute;left: 0px;top:0px;"></ul>
				      <div style="clear: both;"></div>
				      <div class="tab-content" id="consoleTabContent" style="overflow: auto;height: 100%;padding-top: 30px;"></div>
				    </div>
  				</div>
  			</div>
  		</div>
	  </div>
	</div>
	<div style="display: none;">
		<table id="tableModel" class="table table-bordered table-hover table-sm">
			<thead class="thead-light position-static"><tr></tr></thead>
			<tbody></tbody>
		</table>
	</div>
	<script type="text/javascript">
        // trigger extension
        var langTools = ace.require("ace/ext/language_tools");
        var editor = ace.edit("editor");
        editor.session.setMode("ace/mode/mysql");
        editor.setTheme("ace/theme/github");
        editor.setFontSize(18);
        // enable autocompletion and snippets
        editor.setOptions({
            enableBasicAutocompletion: true,
            enableSnippets: true,
            enableLiveAutocompletion: true
        });
        //获取光标处SQL语句块
        editor.getTextCursorRange = function(){
        	//行数 
        	var lines = this.session.getLength();
        	//光标行 
        	var line = this.selection.getCursor().row;
        	//结束位置 
        	var end = {
        		row:lines,
        		column:0
        	};
        	for(var i=line;i<lines;i++){
				var lineRange = {
					start : {
						row : i,
						column : 0
					},
					end : {
						row : i + 1,
						column : 0
					}
				};
				var lineText = this.session.getTextRange(lineRange);
				if (!lineText.replace(/^\s+/, '')) {
					return "";
				}
				if (lineText.indexOf(';') > -1) {
					end = lineRange.end;
					break;
				}
			}
			var start = {
				row : 0,
				column : 0
			};
			for (var i = line; i > 0; i--) {
				var lineRange = {
					start : {
						row : i - 1,
						column : 0
					},
					end : {
						row : i,
						column : 0
					}
				};
				var lineText = this.session.getTextRange(lineRange);
				if (lineText.indexOf(';') > -1) {
					start = lineRange.end;
					break;
				}
			}
			return this.session.getTextRange({
				start : start,
				end : end
			});
		};

        $.post('${path}/sql/autocompleteTable',{},function(data, status, xhr){
            if(data.code == 200){
                langTools.addCompleter({
                    getCompletions: function(editor, session, pos, prefix, callback) {
                        if (prefix.length === 0) { callback(null, []); return }
                        callback(null,data.value);
                    }
                });
            }
        });
	</script>
</body>
</html>