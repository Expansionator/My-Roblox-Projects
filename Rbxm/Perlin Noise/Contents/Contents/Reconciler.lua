--!nocheck
-- @fattah412

--[[

Reconciler:
A module that can fill in any missing values in a table using a template.

-------------------------------------------------------------

Notes:

- This module will not fill in values if the value from the template is nil. For example: ["Test"] = nil
- Any new data that is not in the template but is for the main table, will also be included
- Both the main and the template table must be a table

-------------------------------------------------------------

Usage:

Reconciler.Reconcile(TargetTable: {}, TemplateTable: {}, ReplaceType: boolean?)
> Description: Updates the target table using an existing template
> Returns: nil | void

Reconciler.Copy(TargetTable: {}, TemplateTable: {}, ReplaceType: boolean?): {}
> Description: Returns a copy of the new modified target table
> Returns: {}

-------------------------------------------------------------

Example Usage:

local Reconciler = require(game.ServerScriptService.Reconciler)

local MainTable = {
	Str = "Hello!";
	TestTable = {1000};
}

local TemplateTable = {
	Str = true;
	Example = false;
	TestTable = {1, 2, {
		Index = "Cool Value";
		{Test = -10};
	}};
}

Reconciler.Reconcile(MainTable, TemplateTable)
print("New Table:", MainTable)

-------------------------------------------------------------

]]

local Reconciler = {}

local function duplicateTable(table: {}): {}
	local newTable = {}
	for index, value in table do
		if typeof(value) == "table" then
			value = duplicateTable(value)
		end
		newTable[index] = value
	end

	return newTable
end

function Reconciler.Reconcile(TargetTable: {}, TemplateTable: {}, ReplaceType: boolean?)
	for index, value in TemplateTable do
		local isTypeIdentical = typeof(value) == typeof(TargetTable[index])
		if TargetTable[index] == nil then
			TargetTable[index] = value
			continue
		end

		if ReplaceType and not isTypeIdentical then
			TargetTable[index] = value
			continue
		end

		if isTypeIdentical and typeof(value) == "table" then
			Reconciler.Reconcile(TargetTable[index], value, ReplaceType)
		end
	end
end

function Reconciler.Copy(TargetTable: {}, TemplateTable: {}, ReplaceType: boolean?): {}
	local duplicate = duplicateTable(TargetTable)
	Reconciler.Reconcile(duplicate, TemplateTable, ReplaceType)

	return duplicate
end

return Reconciler